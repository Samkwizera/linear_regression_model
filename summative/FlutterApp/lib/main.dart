import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const String kApiBaseUrl = 'https://insuarance-charges-api.onrender.com';

const _kBg      = Color(0xFF111111);
const _kSurface = Color(0xFF1E1E1E);
const _kCard    = Color(0xFF242424);
const _kOrange  = Color(0xFFFF6200);
const _kOrangeL = Color(0xFFFF8C42);
const _kBorder  = Color(0xFF2E2E2E);
const _kText    = Color(0xFFFFFFFF);
const _kTextSub = Color(0xFF9E9E9E);
const _kErr     = Color(0xFFFF4444);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MediCost AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _kBg,
          colorScheme: const ColorScheme.dark(
            primary: _kOrange,
            surface: _kSurface,
          ),
        ),
        home: const PredictionPage(),
      );
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});
  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final _formKey  = GlobalKey<FormState>();
  final _ageCtr   = TextEditingController();
  final _bmiCtr   = TextEditingController();
  final _childCtr = TextEditingController();

  String? _sex, _smoker, _region;
  bool    _loading = false;

  @override
  void dispose() {
    _ageCtr.dispose();
    _bmiCtr.dispose();
    _childCtr.dispose();
    super.dispose();
  }

  void _showResultDialog(double amount) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: _kOrange.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: _kOrange.withValues(alpha: 0.18),
                  blurRadius: 50,
                  spreadRadius: 4),
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 30),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76, height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kOrange, _kOrangeL],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _kOrange.withValues(alpha: 0.45),
                        blurRadius: 24,
                        spreadRadius: 2)
                  ],
                ),
                child: const Icon(Icons.health_and_safety_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),
              const Text('Estimated Annual Cost',
                  style: TextStyle(
                      fontSize: 14,
                      color: _kTextSub,
                      letterSpacing: 0.5)),
              const SizedBox(height: 14),
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: _kText,
                    letterSpacing: -2),
              ),
              const SizedBox(height: 4),
              const Text('per year',
                  style: TextStyle(fontSize: 14, color: _kTextSub)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _kOrange.withValues(alpha: 0.25)),
                ),
                child: Text(
                  amount < 10000
                      ? '✦  Low Risk'
                      : amount < 20000
                          ? '✦  Medium Risk'
                          : '✦  High Risk',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: amount < 10000
                          ? Colors.greenAccent
                          : amount < 20000
                              ? _kOrangeL
                              : _kErr),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: _kErr.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: _kErr.withValues(alpha: 0.15),
                  blurRadius: 50,
                  spreadRadius: 4),
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 30),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76, height: 76,
                decoration: BoxDecoration(
                  color: _kErr.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _kErr.withValues(alpha: 0.35), width: 1.5),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: _kErr, size: 36),
              ),
              const SizedBox(height: 24),
              const Text('Prediction Failed',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _kErr)),
              const SizedBox(height: 12),
              Text(error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: _kTextSub, height: 1.6)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kErr.withValues(alpha: 0.15),
                    foregroundColor: _kErr,
                    elevation: 0,
                    side: BorderSide(color: _kErr.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Close',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // bounds match the training dataset range
  String? _vAge(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null) return 'Enter a valid number';
    if (n < 18 || n > 64) return 'Age must be 18 – 64';
    return null;
  }

  String? _vBmi(String? v) {
    final n = double.tryParse(v ?? '');
    if (n == null) return 'Enter a decimal number';
    if (n < 10 || n > 60) return 'BMI must be 10.0 – 60.0';
    return null;
  }

  String? _vChildren(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null) return 'Enter a whole number';
    if (n < 0 || n > 5) return 'Must be 0 – 5';
    return null;
  }

  Future<void> _predict() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_sex == null || _smoker == null || _region == null) {
      _showErrorDialog('Please complete all fields before predicting.');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'age':      int.parse(_ageCtr.text.trim()),
          'sex':      _sex,
          'bmi':      double.parse(_bmiCtr.text.trim()),
          'children': int.parse(_childCtr.text.trim()),
          'smoker':   _smoker,
          'region':   _region,
        }),
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final amount = (data['predicted_charges'] as num).toDouble();
        _showResultDialog(amount);
      } else {
        String detail = 'Server error (${res.statusCode}).';
        try {
          final e = jsonDecode(res.body);
          if (e is Map && e['detail'] != null) detail = e['detail'].toString();
        } catch (_) {}
        _showErrorDialog(detail);
      }
    } catch (e) {
      _showErrorDialog(
          'Unable to reach server.\nCheck your internet connection.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionCard(
                        title: 'PERSONAL INFORMATION',
                        children: [
                          _buildField(
                            ctrl: _ageCtr,
                            label: 'Age',
                            hint: '18 – 64 years',
                            icon: Icons.person_outline_rounded,
                            type: TextInputType.number,
                            validator: _vAge,
                            formatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                          _divider(),
                          _buildDropdown(
                            label: 'Biological Sex',
                            icon: Icons.wc_outlined,
                            value: _sex,
                            items: const {
                              'male': 'Male',
                              'female': 'Female'
                            },
                            onChanged: (v) =>
                                setState(() => _sex = v),
                          ),
                          _divider(),
                          _buildField(
                            ctrl: _bmiCtr,
                            label: 'BMI',
                            hint: '10.0 – 60.0 kg/m²',
                            icon: Icons.monitor_weight_outlined,
                            type: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: _vBmi,
                          ),
                          _divider(),
                          _buildField(
                            ctrl: _childCtr,
                            label: 'Number of Children',
                            hint: '0 – 5 dependents',
                            icon: Icons.family_restroom_outlined,
                            type: TextInputType.number,
                            validator: _vChildren,
                            formatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        title: 'LIFESTYLE & LOCATION',
                        children: [
                          _buildDropdown(
                            label: 'Smoking Status',
                            icon: Icons.smoking_rooms_outlined,
                            value: _smoker,
                            items: const {
                              'no': 'Non-Smoker',
                              'yes': 'Smoker'
                            },
                            onChanged: (v) =>
                                setState(() => _smoker = v),
                          ),
                          _divider(),
                          _buildDropdown(
                            label: 'US Region',
                            icon: Icons.location_on_outlined,
                            value: _region,
                            items: const {
                              'northeast': 'Northeast',
                              'northwest': 'Northwest',
                              'southeast': 'Southeast',
                              'southwest': 'Southwest',
                            },
                            onChanged: (v) =>
                                setState(() => _region = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildPredictButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kOrange, _kOrangeL],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.health_and_safety_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MediCost AI',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _kText,
                      letterSpacing: -0.3)),
              Text('Insurance Cost Predictor',
                  style: TextStyle(fontSize: 12, color: _kTextSub)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _kOrange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: _kOrange, size: 7),
                SizedBox(width: 5),
                Text('AI Model',
                    style: TextStyle(
                        fontSize: 11,
                        color: _kOrange,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kOrange,
                    letterSpacing: 1.2)),
          ),
          ...children,
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
      height: 1,
      indent: 52,
      color: _kBorder.withValues(alpha: 0.6));

  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType type,
    required String? Function(String?) validator,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: _kTextSub),
          const SizedBox(width: 14),
          Expanded(
            child: TextFormField(
              controller: ctrl,
              keyboardType: type,
              inputFormatters: formatters,
              validator: validator,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _kText),
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                labelStyle:
                    const TextStyle(fontSize: 13, color: _kTextSub),
                hintStyle: TextStyle(
                    fontSize: 13,
                    color: _kTextSub.withValues(alpha: 0.5)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
                isDense: true,
                errorStyle:
                    const TextStyle(color: _kErr, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required Map<String, String> items,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: _kTextSub),
          const SizedBox(width: 14),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value,
              isExpanded: true,
              dropdownColor: _kCard,
              borderRadius: BorderRadius.circular(14),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: _kTextSub, size: 20),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _kText),
              decoration: InputDecoration(
                labelText: label,
                labelStyle:
                    const TextStyle(fontSize: 13, color: _kTextSub),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
                isDense: true,
                errorStyle:
                    const TextStyle(color: _kErr, fontSize: 11),
              ),
              hint: Text('Select an option',
                  style: TextStyle(
                      fontSize: 13,
                      color: _kTextSub.withValues(alpha: 0.5))),
              items: items.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value,
                            style: const TextStyle(
                                fontSize: 15,
                                color: _kText,
                                fontWeight: FontWeight.w500)),
                      ))
                  .toList(),
              onChanged: onChanged,
              validator: (v) =>
                  v == null ? 'Please select an option' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _loading ? null : _predict,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kOrange,
          disabledBackgroundColor: _kBorder,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Text('Predict',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: Colors.white)),
      ),
    );
  }
}
