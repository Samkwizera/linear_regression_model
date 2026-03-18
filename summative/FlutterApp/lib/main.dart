import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const String kApiBaseUrl = 'https://insuarance-charges-api.onrender.com';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _c1  = Color(0xFF0D1B2A);   // deep navy
const _c2  = Color(0xFF1B4F72);   // mid blue
const _c3  = Color(0xFF2E86AB);   // accent blue
const _c4  = Color(0xFF00C9A7);   // teal green
const _cBg = Color(0xFFF0F4F8);
const _cCard = Colors.white;
const _cErr  = Color(0xFFD32F2F);

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
        theme: ThemeData(useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: _c3)),
        home: const PredictionPage(),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});
  @override
  State<PredictionPage> createState() => _State();
}

class _State extends State<PredictionPage> with TickerProviderStateMixin {
  final _form       = GlobalKey<FormState>();
  final _ageCtrl    = TextEditingController();
  final _bmiCtrl    = TextEditingController();
  final _kidCtrl    = TextEditingController();

  String? _sex, _smoker, _region;
  bool    _loading  = false;
  double? _charges;
  String  _errMsg   = '';

  late final AnimationController _heroAnim;
  late final AnimationController _resultAnim;
  late final Animation<double>   _heroFade, _resultFade;
  late final Animation<Offset>   _resultSlide;

  @override
  void initState() {
    super.initState();
    _heroAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _heroFade = CurvedAnimation(parent: _heroAnim, curve: Curves.easeOut);
    _heroAnim.forward();

    _resultAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _resultFade  = CurvedAnimation(parent: _resultAnim, curve: Curves.easeOut);
    _resultSlide = Tween<Offset>(begin: const Offset(0, .4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _resultAnim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ageCtrl.dispose(); _bmiCtrl.dispose(); _kidCtrl.dispose();
    _heroAnim.dispose(); _resultAnim.dispose();
    super.dispose();
  }

  // ── validators ───────────────────────────────────────────────────────────────
  String? _vAge(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null) return 'Enter a whole number';
    if (n < 18 || n > 64) return 'Must be 18 – 64';
    return null;
  }
  String? _vBmi(String? v) {
    final n = double.tryParse(v ?? '');
    if (n == null) return 'Enter a decimal number';
    if (n < 10 || n > 60) return 'Must be 10.0 – 60.0';
    return null;
  }
  String? _vKid(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null) return 'Enter a whole number';
    if (n < 0 || n > 5) return 'Must be 0 – 5';
    return null;
  }

  // ── predict ───────────────────────────────────────────────────────────────────
  Future<void> _predict() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    if (_sex == null || _smoker == null || _region == null) {
      setState(() { _charges = null; _errMsg = 'Please complete all fields.'; });
      _resultAnim.forward(from: 0);
      return;
    }
    setState(() { _loading = true; _charges = null; _errMsg = ''; });
    try {
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'age': int.parse(_ageCtrl.text.trim()),
          'sex': _sex,
          'bmi': double.parse(_bmiCtrl.text.trim()),
          'children': int.parse(_kidCtrl.text.trim()),
          'smoker': _smoker,
          'region': _region,
        }),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _charges = (data['predicted_charges'] as num).toDouble());
      } else {
        String detail = 'Server error (${res.statusCode}).';
        try {
          final e = jsonDecode(res.body);
          if (e is Map && e['detail'] != null) detail = e['detail'].toString();
        } catch (_) {}
        setState(() => _errMsg = detail);
      }
    } catch (e) {
      setState(() => _errMsg = 'Cannot reach server.\nCheck your connection.');
    } finally {
      setState(() => _loading = false);
      _resultAnim.forward(from: 0);
    }
  }

  // ═══════════════════════════ BUILD ══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      body: CustomScrollView(
        slivers: [
          _hero(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 48),
            sliver: SliverList(delegate: SliverChildListDelegate([
              const SizedBox(height: 24),
              Form(
                key: _form,
                child: Column(children: [
                  _section('Patient Profile', Icons.person_rounded, _c3, [
                    _tile(Icons.cake_rounded, const Color(0xFF5C6BC0),
                      _textField(_ageCtrl, 'Age', '18 – 64 yrs',
                          TextInputType.number, _vAge,
                          [FilteringTextInputFormatter.digitsOnly])),
                    _tile(Icons.wc_rounded, const Color(0xFF8E24AA),
                      _drop('Sex', _sex, ['male','female'],
                          ['Male','Female'], (v) => setState(() => _sex = v))),
                    _tile(Icons.monitor_weight_rounded, const Color(0xFF00897B),
                      _textField(_bmiCtrl, 'BMI', '10.0 – 60.0 kg/m²',
                          const TextInputType.numberWithOptions(decimal: true),
                          _vBmi, null)),
                    _tile(Icons.family_restroom_rounded, const Color(0xFFE65100),
                      _textField(_kidCtrl, 'Dependents', '0 – 5 children',
                          TextInputType.number, _vKid,
                          [FilteringTextInputFormatter.digitsOnly])),
                  ]),
                  const SizedBox(height: 20),
                  _section('Lifestyle & Location', Icons.tune_rounded, _c4, [
                    _tile(Icons.smoking_rooms_rounded, const Color(0xFFC62828),
                      _drop('Smoker', _smoker, ['no','yes'],
                          ['Non-Smoker','Smoker'],
                          (v) => setState(() => _smoker = v))),
                    _tile(Icons.map_rounded, const Color(0xFF2E7D32),
                      _drop('US Region', _region,
                          ['northeast','northwest','southeast','southwest'],
                          ['Northeast','Northwest','Southeast','Southwest'],
                          (v) => setState(() => _region = v))),
                  ]),
                  const SizedBox(height: 32),
                  _predictBtn(),
                  const SizedBox(height: 24),
                  if (_charges != null || _errMsg.isNotEmpty) _result(),
                ]),
              ),
            ])),
          ),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────────
  Widget _hero() => SliverAppBar(
    expandedHeight: 220,
    pinned: true,
    stretch: true,
    backgroundColor: _c1,
    flexibleSpace: FlexibleSpaceBar(
      stretchModes: const [StretchMode.zoomBackground],
      background: Stack(fit: StackFit.expand, children: [
        // gradient
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_c1, _c2, _c3],
          ),
        )),
        // blob decorations
        Positioned(top: -50, right: -50,
          child: _blob(200, Colors.white.withValues(alpha: 0.05))),
        Positioned(bottom: -20, left: -30,
          child: _blob(150, Colors.white.withValues(alpha: 0.04))),
        Positioned(top: 40, right: 60,
          child: _blob(80, _c4.withValues(alpha: 0.18))),
        Positioned(bottom: 30, right: 30,
          child: _blob(50, Colors.white.withValues(alpha: 0.08))),
        // content
        FadeTransition(opacity: _heroFade,
          child: Positioned(bottom: 28, left: 22, right: 22,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_c4, _c4.withValues(alpha: .6)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: _c4.withValues(alpha: .4),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.health_and_safety_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('MediCost AI',
                      style: TextStyle(color: Colors.white, fontSize: 26,
                          fontWeight: FontWeight.w800, letterSpacing: -.5)),
                  Text('Smart insurance cost prediction',
                      style: TextStyle(color: Colors.white.withValues(alpha: .75),
                          fontSize: 13)),
                ]),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                _pill(Icons.model_training, 'Decision Tree'),
                const SizedBox(width: 8),
                _pill(Icons.analytics_rounded, 'R² = 0.89'),
                const SizedBox(width: 8),
                _pill(Icons.dataset_rounded, '1,337 samples'),
              ]),
            ]),
          )),
      ]),
    ),
  );

  Widget _blob(double s, Color c) =>
      Container(width: s, height: s,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c));

  Widget _pill(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: .2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: _c4, size: 12),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white,
          fontSize: 11, fontWeight: FontWeight.w500)),
    ]),
  );

  // ── Section card ──────────────────────────────────────────────────────────────
  Widget _section(String title, IconData icon, Color color, List<Widget> fields) {
    return Container(
      decoration: BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: _c1.withValues(alpha: .07),
              blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withValues(alpha: .03),
              blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: .6)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.w700, color: _c1)),
          ]),
        ),
        const SizedBox(height: 8),
        // fields
        ...fields,
        const SizedBox(height: 8),
      ]),
    );
  }

  // ── Row tile ──────────────────────────────────────────────────────────────────
  Widget _tile(IconData icon, Color color, Widget field) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: field),
        ]),
      ),
      Divider(height: 1, indent: 64, endIndent: 16,
          color: _cBg),
    ]);
  }

  // ── Styled text field ─────────────────────────────────────────────────────────
  Widget _textField(
    TextEditingController ctrl,
    String label,
    String hint,
    TextInputType kbType,
    String? Function(String?) validator,
    List<TextInputFormatter>? formatters,
  ) {
    return TextFormField(
      controller: ctrl,
      keyboardType: kbType,
      validator: validator,
      inputFormatters: formatters,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _c1),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        isDense: true,
      ),
    );
  }

  // ── Styled dropdown ───────────────────────────────────────────────────────────
  Widget _drop(
    String label,
    String? value,
    List<String> vals,
    List<String> display,
    void Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      icon: Icon(Icons.keyboard_arrow_down_rounded,
          color: _c3, size: 22),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _c1),
      dropdownColor: _cCard,
      borderRadius: BorderRadius.circular(16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        isDense: true,
      ),
      hint: Text('Select', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
      items: List.generate(vals.length,
          (i) => DropdownMenuItem(value: vals[i], child: Text(display[i]))),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  // ── Predict button ────────────────────────────────────────────────────────────
  Widget _predictBtn() => GestureDetector(
    onTap: _loading ? null : _predict,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: _loading
            ? LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400])
            : const LinearGradient(
                colors: [_c1, _c2, _c3],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        boxShadow: _loading ? [] : [
          BoxShadow(color: _c3.withValues(alpha: .45),
              blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: _c1.withValues(alpha: .3),
              blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Center(
        child: _loading
            ? const SizedBox(width: 26, height: 26,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Predict',
                    style: TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w800, letterSpacing: .5)),
              ]),
      ),
    ),
  );

  // ── Result card ───────────────────────────────────────────────────────────────
  Widget _result() => FadeTransition(
    opacity: _resultFade,
    child: SlideTransition(
      position: _resultSlide,
      child: _errMsg.isNotEmpty ? _errCard() : _successCard(),
    ),
  );

  Widget _successCard() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF004D40), Color(0xFF00796B), Color(0xFF00BFA5)],
      ),
      boxShadow: [
        BoxShadow(color: const Color(0xFF00796B).withValues(alpha: .4),
            blurRadius: 30, offset: const Offset(0, 14)),
      ],
    ),
    padding: const EdgeInsets.all(30),
    child: Column(children: [
      // top row
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Estimated Cost',
              style: TextStyle(color: Colors.white.withValues(alpha: .8),
                  fontSize: 12, letterSpacing: 1.2,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          const Text('Annual Insurance Charges',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ]),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
        ),
      ]),
      const SizedBox(height: 28),
      // amount
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .2)),
        ),
        child: Column(children: [
          Text('\$${_charges!.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 48,
                  fontWeight: FontWeight.w900, letterSpacing: -2)),
          const SizedBox(height: 4),
          Text('per year',
              style: TextStyle(color: Colors.white.withValues(alpha: .7),
                  fontSize: 14)),
        ]),
      ),
      const SizedBox(height: 20),
      // footer chips
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _resultChip(Icons.psychology_rounded, 'Decision Tree Model'),
        const SizedBox(width: 8),
        _resultChip(Icons.verified_rounded, 'R² 0.89'),
      ]),
    ]),
  );

  Widget _resultChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 13),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white,
          fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _errCard() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5F5),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
      boxShadow: [BoxShadow(color: _cErr.withValues(alpha: .08),
          blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _cErr.withValues(alpha: .1), shape: BoxShape.circle),
        child: const Icon(Icons.error_rounded, color: _cErr, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Prediction Failed',
              style: TextStyle(color: _cErr, fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 4),
          Text(_errMsg,
              style: TextStyle(color: _cErr.withValues(alpha: .8),
                  fontSize: 13, height: 1.5)),
        ],
      )),
    ]),
  );
}
