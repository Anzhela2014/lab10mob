import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:slot_machine_reznik/slot_row.dart';
import 'sound_service.dart';

class SlotMachine extends StatefulWidget {
  const SlotMachine({super.key, this.sound});
  final SoundService? sound;

  @override
  State<SlotMachine> createState() => _SlotMachineState();
}

class _SlotMachineState extends State<SlotMachine> with WidgetsBindingObserver {
  final _random = Random();
  
  final List<String> _symbols = [
    'assets/images/cherry.png',
    'assets/images/lemon.png',
    'assets/images/seven.png',
  ];

  int _coins = 10;
  String _slot1 = 'assets/images/cherry.png';
  String _slot2 = 'assets/images/lemon.png';
  String _slot3 = 'assets/images/seven.png';
  String _message = '';
  bool _isSpinning = false;
  bool _isJackpot = false;

  late final SoundService _sound;
  late final bool _ownsSound;
  bool _soundBusy = false;
  String? _soundError;

  @override
  void initState() {
    super.initState();
    _ownsSound = widget.sound == null;
    _sound = widget.sound ?? SoundService();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_sound.init());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      unawaited(_muteForLifecycle());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsSound) unawaited(_sound.dispose());
    super.dispose();
  }

  Future<void> _toggleMute() async {
    if (_soundBusy) return;
    setState(() => _soundBusy = true);
    await _sound.setMuted(!_sound.isMuted);
    if (!mounted) return;
    setState(() {
      _soundBusy = false;
      _soundError = _sound.lastError;
    });
  }

  Future<void> _muteForLifecycle() async {
    await _sound.setMuted(true);
    if (mounted) setState(() {});
  }

  Future<String> _spinReel({required int totalTicks, required void Function(String) onTick}) async {
    String result = _symbols[0];
    for (int i = 0; i < totalTicks; i++) {
      final double progress = i / totalTicks;
      final int delay = progress < 0.5 ? 40 : progress < 0.8 ? 100 : 200;
      await Future.delayed(Duration(milliseconds: delay));
      if (!mounted) return result;
      result = _symbols[_random.nextInt(_symbols.length)];
      onTick(result);
    }
    return result;
  }

  Future<void> _spin() async {
    if (!mounted || _coins <= 0 || _isSpinning) return;

    setState(() {
      _isSpinning = true;
      _isJackpot = false;
      _message = '';
    });

    unawaited(_sound.playClick());

    final results = await Future.wait([
      _spinReel(totalTicks: 10, onTick: (val) => setState(() => _slot1 = val)),
      _spinReel(totalTicks: 13, onTick: (val) => setState(() => _slot2 = val)),
      _spinReel(totalTicks: 16, onTick: (val) => setState(() => _slot3 = val)),
    ]);

    if (!mounted) return;
    final isWin = results[0] == results[1] && results[1] == results[2];
    final isJackpot = isWin && results[0] == 'assets/images/seven.png';

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _isSpinning = false;
      _isJackpot = isJackpot;

      if (isJackpot) {
        _coins += 10;
        _message = 'ДЖЕКПОТ! 🎰🎰🎰 +10 монет';
      } else if (isWin) {
        _coins += 3;
        _message = 'Победа! 🎉 +3 монеты';
      } else {
        _coins -= 1;
        _message = 'Попробуй ещё раз 😔 -1 монета';
      }

      if (_coins <= 0) {
        _message = 'Монеты закончились! 😢';
      }
    });

    if (isJackpot) {
      unawaited(_sound.playJackpot());
    } else if (isWin) {
      unawaited(_sound.playWin());
    } else {
      unawaited(_sound.playLose());
    }
  }

  void _reset() {
    if (_isSpinning) return;
    setState(() {
      _coins = 10;
      _slot1 = 'assets/images/cherry.png';
      _slot2 = 'assets/images/lemon.png';
      _slot3 = 'assets/images/seven.png';
      _message = '';
      _isJackpot = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              tooltip: _sound.isMuted ? 'Включить звук' : 'Выключить звук',
              onPressed: _soundBusy ? null : _toggleMute,
              icon: Icon(_sound.isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
            ),
          ),
        ),
        if (_soundError != null)
          const Text('Не удалось включить звук.', style: TextStyle(color: Colors.white70)),
        Text(
          '💰 Монеты: $_coins',
          style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 40),
        AnimatedOpacity(
          opacity: _isSpinning ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: SlotRow(slot1: _slot1, slot2: _slot2, slot3: _slot3),
        ),
        const SizedBox(height: 40),
        SizedBox(
          height: 36,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _isSpinning ? '🎰 Крутим...' : _message,
              key: ValueKey(_isSpinning ? 'spinning' : _message),
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: _isJackpot ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _coins > 0 && !_isSpinning ? _spin : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
          ),
          child: Text(
            _isSpinning ? '🎰 Крутим...' : 'КРУТИТЬ 🎰',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isSpinning ? null : _reset,
          child: const Text('Начать заново', style: TextStyle(color: Colors.white70, fontSize: 16)),
        ),
      ],
    );
  }
}