# Medical Insurance Charges Predictor

**Mission:** Identify the key factors that drive individual healthcare costs in the United States to help insurers and policymakers design more equitable and affordable medical coverage.

**Dataset:** Medical Cost Personal Dataset — 1,338 records with 6 features (age, sex, BMI, children, smoker status, region). Source: [Kaggle - Medical Cost Personal Dataset](https://www.kaggle.com/datasets/mirichoi0218/insurance). The dataset covers diverse demographics across four US regions, providing rich variety for regression analysis.

**Live API (Swagger UI):** https://insuarance-charges-api.onrender.com/docs

**Video Demo:** https://youtu.be/HFJpw1joXHE

---

## How to Run the Flutter App

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.10 or higher)
- An Android emulator, iOS simulator, or physical device

### Steps
```bash
# 1. Clone the repository
git clone https://github.com/Samkwizera/linear_regression_model.git

# 2. Navigate to the Flutter app
cd linear_regression_model/summative/FlutterApp

# 3. Install dependencies
flutter pub get

# 4. Run the app
flutter run
```

> The app connects to the live API at `https://insuarance-charges-api.onrender.com`.
> If the API is cold (free tier), the first prediction may take ~30 seconds to respond.

---

## Project Structure

```
summative/
├── linear_regression/
│   └── multivariate.ipynb       # EDA, feature engineering, model training
├── API/
│   ├── prediction.py            # FastAPI app with /predict and /retrain endpoints
│   ├── requirements.txt         # Python dependencies
│   ├── best_model.pkl           # Saved Decision Tree model
│   └── scaler.pkl               # Saved StandardScaler
└── FlutterApp/
    └── lib/main.dart            # Flutter prediction app
```
