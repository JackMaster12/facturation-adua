import 'package:flutter/material.dart';

/// Écran d'ouverture animé : le logo apparaît en grossissant, le titre s'écrit
/// lettre par lettre, puis l'application s'affiche en fondu.
class EcranDemarrage extends StatefulWidget {
  const EcranDemarrage({super.key, required this.suite});

  /// Écran affiché une fois l'animation terminée.
  final Widget suite;

  @override
  State<EcranDemarrage> createState() => _EcranDemarrageState();
}

class _EcranDemarrageState extends State<EcranDemarrage> with SingleTickerProviderStateMixin {
  static const _titre = 'FACTURATION ADUA';
  static const _sousTitre = 'Dépôt Pharmaceutique · Zinder';

  late final AnimationController _ctrl;
  late final Animation<double> _logo;
  late final Animation<double> _logoOpacite;
  late final Animation<double> _lettres;
  late final Animation<double> _sousTitreOpacite;
  late final Animation<double> _barre;
  bool _fini = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
    _logo = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.40, curve: Curves.easeOutBack));
    _logoOpacite = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.25, curve: Curves.easeIn));
    _lettres = CurvedAnimation(parent: _ctrl, curve: const Interval(0.35, 0.75, curve: Curves.linear));
    _sousTitreOpacite = CurvedAnimation(parent: _ctrl, curve: const Interval(0.72, 0.92, curve: Curves.easeIn));
    _barre = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 1.0, curve: Curves.easeInOut));
    _ctrl.forward().whenComplete(() {
      if (mounted) setState(() => _fini = true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _fini ? KeyedSubtree(key: const ValueKey('app'), child: widget.suite) : _splash(),
    );
  }

  Widget _splash() {
    return Scaffold(
      key: const ValueKey('splash'),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B6E4F), Color(0xFF074D38)],
          ),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final n = (_lettres.value * _titre.length).round().clamp(0, _titre.length);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: _logoOpacite.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: _logo.value.clamp(0.0, 1.3),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset('assets/icone.png', width: 130, height: 130),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 32,
                  child: Text(
                    _titre.substring(0, n) + (n < _titre.length && _lettres.value > 0 ? '▌' : ''),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: _sousTitreOpacite.value.clamp(0.0, 1.0),
                  child: const Text(_sousTitre,
                      style: TextStyle(color: Color(0xFFFFD966), fontSize: 14, letterSpacing: 1)),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _barre.value,
                      minHeight: 4,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD966)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
