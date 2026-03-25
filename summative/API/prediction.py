import csv
import io
import os

import joblib
import numpy as np
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeRegressor
from typing import Literal

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "best_model.pkl")
SCALER_PATH = os.path.join(BASE_DIR, "scaler.pkl")

model = joblib.load(MODEL_PATH)
scaler = joblib.load(SCALER_PATH)

app = FastAPI(
    title="Healthcare Insurance Charges Prediction API",
    description=(
        "Predicts annual medical insurance charges based on patient demographics. "
        "Trained on the Medical Cost Personal Dataset (Kaggle). "
        "Best model: Decision Tree (R² = 0.8924)."
    ),
    version="1.0.0",
)

# no wildcard origins — locks down which frontends can call this API
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:8080",
        "http://10.0.2.2:8000",   
        "https://insuarance-charges-api.onrender.com",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization", "Accept"],
)

class InsuranceInput(BaseModel):
    age: int = Field(
        ..., ge=18, le=64,
        description="Age of the insured individual (18–64 years)",
        example=35,
    )
    sex: Literal["male", "female"] = Field(
        ...,
        description="Biological sex of the individual",
        example="male",
    )
    bmi: float = Field(
        ..., ge=10.0, le=60.0,
        description="Body Mass Index (10.0–60.0 kg/m²)",
        example=28.5,
    )
    children: int = Field(
        ..., ge=0, le=5,
        description="Number of dependents covered by the plan (0–5)",
        example=2,
    )
    smoker: Literal["yes", "no"] = Field(
        ...,
        description="Whether the individual is a smoker",
        example="no",
    )
    region: Literal["northeast", "northwest", "southeast", "southwest"] = Field(
        ...,
        description="US residential region",
        example="northeast",
    )


class PredictionResponse(BaseModel):
    predicted_charges: float = Field(description="Predicted annual insurance charges in USD")
    message: str


class RetrainResponse(BaseModel):
    message: str
    r2_score: float
    samples_used: int


# order must match the LabelEncoder used during training; changing these breaks predictions silently
REGION_MAP = {"northeast": 0, "northwest": 1, "southeast": 2, "southwest": 3}


def encode_and_scale(data: InsuranceInput) -> np.ndarray:
    sex_enc = 1 if data.sex == "male" else 0
    smoker_enc = 1 if data.smoker == "yes" else 0
    region_enc = REGION_MAP[data.region]
    features = np.array(
        [[data.age, sex_enc, data.bmi, data.children, smoker_enc, region_enc]],
        dtype=float,
    )
    # transform, not fit_transform — the scaler was already fit on training data
    return scaler.transform(features)


@app.get("/", tags=["Health"])
def root():
    return {
        "status": "online",
        "message": "Healthcare Insurance Charges Prediction API",
        "docs": "/docs",
    }


@app.post("/predict", response_model=PredictionResponse, tags=["Prediction"])
def predict(input_data: InsuranceInput):
    """
    Predict annual medical insurance charges for a patient.

    - **age**: Integer between 18 and 64
    - **sex**: "male" or "female"
    - **bmi**: Float between 10.0 and 60.0
    - **children**: Integer between 0 and 5
    - **smoker**: "yes" or "no"
    - **region**: One of northeast / northwest / southeast / southwest
    """
    scaled = encode_and_scale(input_data)
    prediction = float(model.predict(scaled)[0])
    return PredictionResponse(
        predicted_charges=round(prediction, 2),
        message="Prediction successful",
    )


@app.post("/retrain", response_model=RetrainResponse, tags=["Model Management"])
async def retrain(file: UploadFile = File(...)):
    """
    Retrain the model with a new CSV dataset.

    The CSV must contain these columns:
    `age, sex, bmi, children, smoker, region, charges`

    On success the updated model and scaler are saved to disk and loaded
    into memory immediately — no restart required.
    """
    global model, scaler

    if not (file.filename or "").endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only .csv files are accepted.")

    content = await file.read()
    try:
        reader = csv.DictReader(io.StringIO(content.decode("utf-8")))
        rows = list(reader)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Could not parse CSV: {exc}")

    if not rows:
        raise HTTPException(status_code=422, detail="CSV file is empty.")

    required = {"age", "sex", "bmi", "children", "smoker", "region", "charges"}
    missing = required - set(rows[0].keys())
    if missing:
        raise HTTPException(
            status_code=422,
            detail=f"CSV is missing required columns: {missing}",
        )

    SEX_MAP = {"female": 0, "male": 1}
    SMOKER_MAP = {"no": 0, "yes": 1}

    # seen tracks row fingerprints to drop exact duplicates before training
    X_list, y_list, seen = [], [], set()
    for row in rows:
        try:
            key = tuple(row[c] for c in required)
            if key in seen:
                continue
            seen.add(key)
            x = [
                float(row["age"]),
                float(SEX_MAP[row["sex"].strip().lower()]),
                float(row["bmi"]),
                float(row["children"]),
                float(SMOKER_MAP[row["smoker"].strip().lower()]),
                float(REGION_MAP[row["region"].strip().lower()]),
            ]
            X_list.append(x)
            y_list.append(float(row["charges"]))
        except (KeyError, ValueError):
            continue

    if len(X_list) < 50:
        raise HTTPException(
            status_code=422,
            detail="Dataset too small — need at least 50 valid rows.",
        )

    X = np.array(X_list, dtype=float)
    y = np.array(y_list, dtype=float)

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    new_scaler = StandardScaler()
    X_train_scaled = new_scaler.fit_transform(X_train)
    X_test_scaled = new_scaler.transform(X_test)

    # max_depth=5 matches the original training config so retrained models stay comparable
    new_model = DecisionTreeRegressor(max_depth=5, random_state=42)
    new_model.fit(X_train_scaled, y_train)

    r2 = float(new_model.score(X_test_scaled, y_test))

    # write to disk so the updated model survives a restart
    joblib.dump(new_model, MODEL_PATH)
    joblib.dump(new_scaler, SCALER_PATH)

    # swap into the live process so predictions use the new model immediately
    model = new_model
    scaler = new_scaler

    return RetrainResponse(
        message="Model retrained and updated successfully.",
        r2_score=round(r2, 4),
        samples_used=len(df),
    )
