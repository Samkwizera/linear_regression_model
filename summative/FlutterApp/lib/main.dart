import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ── Update this URL once the API is deployed on Render ───────────────────────
const String kApiBaseUrl = 'https://insurance-charges-api.onrender.com';
// For local testing use: 'http://10.0.2.2:8000' (Android emulator)
//                   or   'http://localhost:8000'  (web / desktop)

void main() => runApp(const InsurancePredictorApp());

class InsurancePredictorApp extends StatelessWidget {
  const InsurancePredictorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Insurance Charges Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const PredictionPage(),
    );
  }
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _ageCtrl = TextEditingController();
  final _bmiCtrl = TextEditingController();
  final _childrenCtrl = TextEditingController();

  // Dropdown values
  String? _sex;
  String? _smoker;
  String? _region;

  // State
  bool _loading = false;
  String _result = '';
  bool _hasError = false;

  @override
  void dispose() {
    _ageCtrl.dispose();
    _bmiCtrl.dispose();
    _childrenCtrl.dispose();
    super.dispose();
  }

  // ── Validation helpers ──────────────────────────────────────────────────────
  String? _validateAge(String? v) {
    if (v == null || v.isEmpty) return 'Age is required';
    final n = int.tryParse(v);
    if (n == null) return 'Enter a valid integer';
    if (n < 18 || n > 64) return 'Age must be between 18 and 64';
    return null;
  }

  String? _validateBmi(String? v) {
    if (v == null || v.isEmpty) return 'BMI is required';
    final n = double.tryParse(v);
    if (n == null) return 'Enter a valid number';
    if (n < 10.0 || n > 60.0) return 'BMI must be between 10.0 and 60.0';
    return null;
  }

  String? _validateChildren(String? v) {
    if (v == null || v.isEmpty) return 'Number of children is required';
    final n = int.tryParse(v);
    if (n == null) return 'Enter a valid integer';
    if (n < 0 || n > 5) return 'Children must be between 0 and 5';
    return null;
  }

  // ── API call ────────────────────────────────────────────────────────────────
  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sex == null || _smoker == null || _region == null) {
      setState(() {
        _hasError = true;
        _result = 'Please select values for Sex, Smoker status, and Region.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _result = '';
      _hasError = false;
    });

    final body = jsonEncode({
      'age': int.parse(_ageCtrl.text.trim()),
      'sex': _sex,
      'bmi': double.parse(_bmiCtrl.text.trim()),
      'children': int.parse(_childrenCtrl.text.trim()),
      'smoker': _smoker,
      'region': _region,
    });

    try {
      final response = await http
          .post(
            Uri.parse('$kApiBaseUrl/predict'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final charges = (data['predicted_charges'] as num).toDouble();
        setState(() {
          _hasError = false;
          _result =
              'Estimated Annual Charges:\n\$${charges.toStringAsFixed(2)}';
        });
      } else {
        String detail = 'Prediction failed (HTTP ${response.statusCode}).';
        try {
          final err = jsonDecode(response.body);
          if (err is Map && err.containsKey('detail')) {
            detail = err['detail'].toString();
          }
        } catch (_) {}
        setState(() {
          _hasError = true;
          _result = detail;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _result = 'Network error: ${e.toString()}';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        title: const Text(
          'Insurance Charges Predictor',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header card
              Card(
                elevation: 0,
                color: Colors.teal.shade50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.health_and_safety,
                          color: Colors.teal, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Enter patient details to predict annual medical insurance costs.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.teal.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              _sectionLabel('Demographics'),
              const SizedBox(height: 12),

              // Age
              _buildTextField(
                controller: _ageCtrl,
                label: 'Age',
                hint: '18 – 64',
                icon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
                validator: _validateAge,
              ),
              const SizedBox(height: 14),

              // Sex
              _buildDropdown(
                label: 'Sex',
                icon: Icons.person_outline,
                value: _sex,
                items: const ['male', 'female'],
                onChanged: (v) => setState(() => _sex = v),
              ),
              const SizedBox(height: 14),

              // BMI
              _buildTextField(
                controller: _bmiCtrl,
                label: 'BMI',
                hint: '10.0 – 60.0',
                icon: Icons.monitor_weight_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: _validateBmi,
              ),
              const SizedBox(height: 14),

              // Children
              _buildTextField(
                controller: _childrenCtrl,
                label: 'Number of Children',
                hint: '0 – 5',
                icon: Icons.child_friendly_outlined,
                keyboardType: TextInputType.number,
                validator: _validateChildren,
              ),

              const SizedBox(height: 24),
              _sectionLabel('Lifestyle & Location'),
              const SizedBox(height: 12),

              // Smoker
              _buildDropdown(
                label: 'Smoker',
                icon: Icons.smoking_rooms_outlined,
                value: _smoker,
                items: const ['no', 'yes'],
                onChanged: (v) => setState(() => _smoker = v),
              ),
              const SizedBox(height: 14),

              // Region
              _buildDropdown(
                label: 'Region',
                icon: Icons.location_on_outlined,
                value: _region,
                items: const [
                  'northeast',
                  'northwest',
                  'southeast',
                  'southwest'
                ],
                onChanged: (v) => setState(() => _region = v),
              ),

              const SizedBox(height: 32),

              // Predict button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _predict,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.calculate_outlined),
                  label: Text(_loading ? 'Predicting…' : 'Predict'),
                ),
              ),

              const SizedBox(height: 24),

              // Result display
              if (_result.isNotEmpty)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _hasError
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    border: Border.all(
                        color: _hasError
                            ? Colors.red.shade200
                            : Colors.green.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _hasError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: _hasError
                            ? Colors.red
                            : Colors.green.shade700,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _result,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: _hasError
                                ? Colors.red.shade800
                                : Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widget helpers ──────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.teal,
          letterSpacing: 1.1,
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.teal),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
      ),
      hint: Text('Select $label'),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Please select $label' : null,
    );
  }
}
