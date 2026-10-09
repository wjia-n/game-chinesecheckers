import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../audio/sound_engine.dart';
import '../services/iap_service.dart';
import '../state/settings.dart';
import '../theme/cc_themes.dart';

/// Chinese Checkers PRO: Free-vs-Pro comparison, real purchase, restore,
/// and tip jar. All prices come from the store — never hardcoded, never
/// placeholders. Graceful "available after store setup" state until Wajiha
/// creates the products in Play Console.
class ProScreen extends StatefulWidget {
  final SoundEngine sound;
  final AppSettings settings;
  final StoreService store;

  const ProScreen({
    super.key,
    required this.sound,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  CcTheme get _t => widget.settings.theme;

  @override
  void initState() {
    super.initState();
    widget.store.proPurchased.addListener(_onPro);
    widget.store.lastThanks.addListener(_onThanks);
  }

  void _onPro() {
    if (widget.store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      widget.sound.play(SfxKind.win);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PRO unlocked — enjoy everything!',
              style: TextStyle(
                  fontFamily: 'serif', fontSize: 15, color: _t.ivory)),
          backgroundColor: _t.panel,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.store.proPurchased.value = false;
    }
  }

  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.sound.play(SfxKind.win);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style:
                TextStyle(fontFamily: 'serif', fontSize: 15, color: _t.ivory)),
        backgroundColor: _t.panel,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store.proPurchased.removeListener(_onPro);
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final store = widget.store;
    return Scaffold(
      backgroundColor: t.silk,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.goldBright),
          onPressed: () {
            widget.sound.play(SfxKind.click);
            Navigator.of(context).pop();
          },
        ),
        title: Text('Chinese Checkers PRO',
            style: TextStyle(
                fontFamily: 'serif',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: t.ivory)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (_, _) => SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              children: [
                _ComparisonCard(theme: t, isPro: s.isPro),
                const SizedBox(height: 16),
                _BuyCard(
                  theme: t,
                  settings: s,
                  store: store,
                  sound: widget.sound,
                ),
                const SizedBox(height: 16),
                _TipsCard(
                  theme: t,
                  store: store,
                  sound: widget.sound,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Free vs Pro comparison table — buyers see the big difference.
class _ComparisonCard extends StatelessWidget {
  final CcTheme theme;
  final bool isPro;
  const _ComparisonCard({required this.theme, required this.isPro});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Complete Chinese Checkers game', true, true),
      ('All official rules enforced', true, true),
      ('Porcelain & Lacquer AI', true, true),
      ('2–6 players pass-and-play', true, true),
      ('Mixed human / bot seats', true, true),
      ('Renameable players', true, true),
      ('Music & sound effects', true, true),
      ('Porcelain themes', '4', '13'),
      ('Marble styles', '4', '10'),
      ('Board accents', '2', '6'),
      ('Custom theme creator', false, true),
      ('Imperial (hard) AI', false, true),
      ('Match scoring across rounds', false, true),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.silkRaised,
        border: Border.all(color: theme.gold, width: 2),
      ),
      child: Column(
        children: [
          Text('Free vs PRO',
              style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.ivory)),
          const SizedBox(height: 4),
          Text(
            'One purchase. Yours forever.',
            style: TextStyle(
                fontFamily: 'serif',
                fontSize: 13,
                color: theme.ivory.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(flex: 5, child: SizedBox()),
              Expanded(
                  flex: 2,
                  child: Text('FREE',
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          color: theme.gold),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('PRO',
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          color: theme.gold),
                      textAlign: TextAlign.center)),
            ],
          ),
          const Divider(height: 14),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(r.$1,
                        style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 13,
                            color: theme.ivory)),
                  ),
                  Expanded(flex: 2, child: _Cell(value: r.$2, theme: theme)),
                  Expanded(flex: 2, child: _Cell(value: r.$3, theme: theme)),
                ],
              ),
            ),
          if (isPro)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: theme.gold.withValues(alpha: 0.25),
                  border: Border.all(color: theme.goldBright),
                ),
                child: Text('✦ PRO ACTIVE ✦',
                    style: TextStyle(
                        fontSize: 14,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                        color: theme.goldBright)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final Object value; // bool | String
  final CcTheme theme;
  const _Cell({required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (value is bool) {
      final v = value as bool;
      return Text(
        v ? '✓' : '—',
        style: TextStyle(
            fontSize: 15,
            color: v
                ? theme.goldBright
                : theme.ivory.withValues(alpha: 0.4)),
        textAlign: TextAlign.center,
      );
    }
    return Text(
      value as String,
      style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: theme.goldBright),
      textAlign: TextAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
class _BuyCard extends StatelessWidget {
  final CcTheme theme;
  final AppSettings settings;
  final StoreService store;
  final SoundEngine sound;
  const _BuyCard({
    required this.theme,
    required this.settings,
    required this.store,
    required this.sound,
  });

  @override
  Widget build(BuildContext context) {
    final pro = store.proProduct;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.silkRaised,
        border: Border.all(color: theme.gold, width: 2),
      ),
      child: Column(
        children: [
          Text('Unlock PRO',
              style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.ivory)),
          const SizedBox(height: 8),
          if (settings.isPro)
            Text('You already own PRO — thank you!',
                style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 14,
                    color: theme.ivory),
                textAlign: TextAlign.center)
          else if (!store.storeReady)
            Text(
              store.error ?? 'Available after store setup.',
              style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 14,
                  color: theme.ivory.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            )
          else if (pro != null) ...[
            Text(
                pro.description.isNotEmpty
                    ? pro.description
                    : 'Unlock everything in Chinese Checkers, forever.',
                style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 14,
                    color: theme.ivory),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: store.purchaseInProgress,
              builder: (_, busy, _) => _ProButton(
                theme: theme,
                label: busy ? 'Working…' : 'Get PRO — ${pro.price}',
                enabled: !busy,
                onTap: () {
                  sound.play(SfxKind.click);
                  store.buyPro();
                },
              ),
            ),
          ],
          ValueListenableBuilder<String?>(
            valueListenable: store.purchaseError,
            builder: (_, err, _) => err == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(err,
                        style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 13,
                            color: const Color(0xFFE08A8A)),
                        textAlign: TextAlign.center),
                  ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              sound.play(SfxKind.click);
              store.restore();
            },
            child: Text('Restore purchases',
                style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                    color: theme.gold)),
          ),
        ],
      ),
    );
  }
}

class _ProButton extends StatelessWidget {
  final CcTheme theme;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _ProButton(
      {required this.theme,
      required this.label,
      required this.enabled,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          width: 260,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.lacquer, theme.lacquerDeep],
            ),
            border: Border.all(color: theme.gold, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.ivory)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Consumable tips — pure support, with real store prices.
class _TipsCard extends StatelessWidget {
  final CcTheme theme;
  final StoreService store;
  final SoundEngine sound;
  const _TipsCard(
      {required this.theme, required this.store, required this.sound});

  @override
  Widget build(BuildContext context) {
    final tips = [
      store.coffeeProduct,
      store.chocolateProduct,
    ].whereType<ProductDetails>().toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.silkRaised,
        border: Border.all(color: theme.gold, width: 2),
      ),
      child: Column(
        children: [
          Text('Tip the Maker',
              style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.ivory)),
          const SizedBox(height: 8),
          Text(
            'Chinese Checkers is free forever. A small tip keeps new games coming!',
            style:
                TextStyle(fontFamily: 'serif', fontSize: 14, color: theme.ivory),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!store.storeReady)
            Text(
              store.error ?? 'Available after store setup.',
              style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 13,
                  color: theme.ivory.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            )
          else if (tips.isEmpty)
            Text('Tips coming soon.',
                style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 13,
                    color: theme.ivory.withValues(alpha: 0.6)))
          else
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  _TipChip(
                    theme: theme,
                    label:
                        '${p.id == StoreService.chocolateId ? '🍫' : '☕'} ${p.price}',
                    onTap: () {
                      sound.play(SfxKind.click);
                      store.buyTip(p);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  final CcTheme theme;
  final String label;
  final VoidCallback onTap;
  const _TipChip(
      {required this.theme, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(
              color: theme.gold.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: theme.goldBright)),
      ),
    );
  }
}
