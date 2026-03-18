import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const String kApiBaseUrl = 'https://insuarance-charges-api.onrender.com';

// ── Palette ──────────────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFF0A6E6E);
const _kAccent    = Color(0xFF00BFA5);
const _kGradStart = Color(0xFF0A6E6E);
const _kGradEnd   = Color(0xFF00BFA5);
const _kBg        = Color(0xFFF0F4F8);
const _kCard      = Colors.white;
const _kError     = Color(0xFFE53935);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const InsurancePredictorApp());
}

class InsurancePredictorApp extends StatelessWidget {
  const InsurancePredictorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediCost Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _kPrimary,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _kCard,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE3EA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE3EA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kAccent, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kError),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kError, width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF607D8B)),
          prefixIconColor: _kPrimary,
        ),
      ),
      home: const PredictionPage(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage>
    with SingleTickerProviderStateMixin {
  final _formKey     = GlobalKey<FormState>();
  final _ageCtrl      = TextEditingController();
  final _bmiCtrl      = TextEditingController();
  final _childrenCtrl = TextEditingController();

  String? _sex;
  String? _smoker;
  String? _region;

  bool    _loading  = false;
  double? _charges;
  bool    _hasError = false;
  String  _errorMsg = '';

  late final AnimationController _resultAnim;
  late final Animation<double>    _resultFade;
  late final Animation<Offset>    _resultSlide;

  @override
  void initState() {
    super.initState();
    _resultAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _resultFade  = CurvedAnimation(parent: _resultAnim, curve: Curves.easeOut);
    _resultSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _resultAnim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _bmiCtrl.dispose();
    _childrenCtrl.dispose();
    _resultAnim.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────────────────────────
  String? _validateAge(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final n = int.tryParse(v);
    if (n == null) return 'Enter a whole number';
    if (n < 18 || n > 64) return 'Must be 18 – 64';
    return null;
  }

  String? _validateBmi(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final n = double.tryParse(v);
    if (n == null) return 'Enter a decimal number';
    if (n < 10.0 || n > 60.0) return 'Must be 10.0 – 60.0';
    return null;
  }

  String? _validateChildren(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final n = int.tryParse(v);
    if (n == null) return 'Enter a whole number';
    if (n < 0 || n > 5) return 'Must be 0 – 5';
    return null;
  }

  // ── API ──────────────────────────────────────────────────────────────────────
  Future<void> _predict() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_sex == null || _smoker == null || _region == null) {
      setState(() {
        _hasError = true;
        _charges  = null;
        _errorMsg = 'Please fill in all dropdown fields.';
      });
      _resultAnim.forward(from: 0);
      return;
    }

    setState(() {
      _loading  = true;
      _charges  = null;
      _hasError = false;
      _errorMsg = '';
    });

    final body = jsonEncode({
      'age':      int.parse(_ageCtrl.text.trim()),
      'sex':      _sex,
      'bmi':      double.parse(_bmiCtrl.text.trim()),
      'children': int.parse(_childrenCtrl.text.trim()),
      'smoker':   _smoker,
      'region':   _region,
    });

    try {
      final res = await http
          .post(
            Uri.parse('$kApiBaseUrl/predict'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data    = jsonDecode(res.body) as Map<String, dynamic>;
        final charges = (data['predicted_charges'] as num).toDouble();
        setState(() {
          _charges  = charges;
          _hasError = false;
        });
      } else {
        String detail = 'Prediction failed (HTTP ${res.statusCode}).';
        try {
          final err = jsonDecode(res.body);
          if (err is Map && err.containsKey('detail')) {
            detail = err['detail'].toString();
          }
        } catch (_) {}
        setState(() {
          _hasError = true;
          _errorMsg = detail;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMsg = 'Could not reach the server.\nCheck your connection and try again.';
      });
    } finally {
      setState(() => _loading = false);
      _resultAnim.forward(from: 0);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          _buildHeroAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    _sectionHeader(
                      icon: Icons.person_rounded,
                      title: 'Patient Profile',
                      subtitle: 'Basic demographic information',
                    ),
                    const SizedBox(height: 16),
                    _buildCard(children: [
                      _field(
                        controller: _ageCtrl,
                        label: 'Age',
                        hint: '18 – 64 years',
                        icon: Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                        validator: _validateAge,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                      _divider(),
                      _dropdown(
                        label: 'Biological Sex',
                        icon: Icons.wc_rounded,
                        value: _sex,
                        items: const ['male', 'female'],
                        displayItems: const ['Male', 'Female'],
                        onChanged: (v) => setState(() => _sex = v),
                      ),
                      _divider(),
                      _field(
                        controller: _bmiCtrl,
                        label: 'BMI (Body Mass Index)',
                        hint: '10.0 – 60.0 kg/m²',
                        icon: Icons.monitor_weight_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _validateBmi,
                      ),
                      _divider(),
                      _field(
                        controller: _childrenCtrl,
                        label: 'Dependents',
                        hint: '0 – 5 children',
                        icon: Icons.family_restroom_rounded,
                        keyboardType: TextInputType.number,
                        validator: _validateChildren,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _sectionHeader(
                      icon: Icons.tune_rounded,
                      title: 'Lifestyle & Location',
                      subtitle: 'Factors that influence insurance cost',
                    ),
                    const SizedBox(height: 16),
                    _buildCard(children: [
                      _dropdown(
                        label: 'Smoking Status',
                        icon: Icons.smoking_rooms_rounded,
                        value: _smoker,
                        items: const ['no', 'yes'],
                        displayItems: const ['Non-Smoker', 'Smoker'],
                        onChanged: (v) => setState(() => _smoker = v),
                      ),
                      _divider(),
                      _dropdown(
                        label: 'US Region',
                        icon: Icons.map_outlined,
                        value: _region,
                        items: const ['northeast', 'northwest', 'southeast', 'southwest'],
                        displayItems: const ['Northeast', 'Northwest', 'Southeast', 'Southwest'],
                        onChanged: (v) => setState(() => _region = v),
                      ),
                    ]),

                    const SizedBox(height: 36),
                    _buildPredictButton(),

                    const SizedBox(height: 28),
                    if (_charges != null || _hasError) _buildResultCard(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero AppBar ──────────────────────────────────────────────────────────────
  Widget _buildHeroAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      backgroundColor: _kPrimary,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kGradStart, _kGradEnd],
                ),
              ),
            ),
            // Decorative circles
            Positioned(
              top: -40, right: -40,
              child: _glowCircle(160, Colors.white.withValues(alpha: 0.07)),
            ),
            Positioned(
              bottom: -30, left: -20,
              child: _glowCircle(120, Colors.white.withValues(alpha: 0.05)),
            ),
            Positioned(
              top: 60, right: 40,
              child: _glowCircle(60, Colors.white.withValues(alpha: 0.1)),
            ),
            // Content
            Positioned(
              bottom: 24, left: 24, right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'MediCost Predictor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI-powered insurance cost estimation',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowCircle(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  // ── Section header ───────────────────────────────────────────────────────────
  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _kPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _kPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2E44))),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF607D8B))),
          ],
        ),
      ],
    );
  }

  // ── Card wrapper ─────────────────────────────────────────────────────────────
  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A6E6E).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: children),
      ),
    );
  }

  Widget _divider() => const Divider(
      height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0F4F8));

  // ── Text field ───────────────────────────────────────────────────────────────
  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        inputFormatters: inputFormatters,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A2E44)),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(icon, size: 20, color: _kPrimary),
          ),
        ),
      ),
    );
  }

  // ── Dropdown ─────────────────────────────────────────────────────────────────
  Widget _dropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required List<String> displayItems,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A2E44)),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(icon, size: 20, color: _kPrimary),
          ),
        ),
        hint: Text('Select an option',
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kPrimary),
        borderRadius: BorderRadius.circular(14),
        items: List.generate(
          items.length,
          (i) => DropdownMenuItem(
            value: items[i],
            child: Text(displayItems[i]),
          ),
        ),
        onChanged: onChanged,
        validator: (v) => v == null ? 'Please make a selection' : null,
      ),
    );
  }

  // ── Predict button ───────────────────────────────────────────────────────────
  Widget _buildPredictButton() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _loading
            ? null
            : const LinearGradient(
                colors: [_kGradStart, _kGradEnd],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        color: _loading ? const Color(0xFFB0BEC5) : null,
        boxShadow: _loading
            ? []
            : [
                BoxShadow(
                  color: _kAccent.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : _predict,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Predict',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Result card ──────────────────────────────────────────────────────────────
  Widget _buildResultCard() {
    return FadeTransition(
      opacity: _resultFade,
      child: SlideTransition(
        position: _resultSlide,
        child: _hasError ? _errorCard() : _successCard(),
      ),
    );
  }

  Widget _successCard() {
    final formatted = '\$${_charges!.toStringAsFixed(2)}';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          // Icon badge
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Estimated Annual Cost',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatted,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'USD per year  •  Decision Tree Model',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _kError.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kError.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_rounded,
                color: _kError, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prediction Error',
                    style: TextStyle(
                        color: _kError,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  _errorMsg,
                  style: TextStyle(
                      color: _kError.withValues(alpha: 0.85),
                      fontSize: 13,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
