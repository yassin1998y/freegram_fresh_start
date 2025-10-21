import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/game_bloc/game_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/game_session.dart';
import 'package:freegram/repositories/game_repository.dart';
import 'package:freegram/screens/game_results_screen.dart';
import 'package:freegram/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/widgets/particle_effects.dart';
import 'package:freegram/widgets/special_effects_overlay.dart';

class Match3Screen extends StatelessWidget {
  final String gameId;
  const Match3Screen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GameBloc(
        gameRepository: locator<GameRepository>(),
        gameId: gameId,
      )..add(LoadGame()),
      child: const _Match3ScreenView(),
    );
  }
}

class _Match3ScreenView extends StatefulWidget {
  const _Match3ScreenView();

  @override
  State<_Match3ScreenView> createState() => _Match3ScreenViewState();
}

class _Match3ScreenViewState extends State<_Match3ScreenView> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  final GlobalKey<_GameBoardState> _gameBoardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: BlocConsumer<GameBloc, GameState>(
        listener: (context, state) {
          if (state is GameLoaded) {
            if (state.gameSession.status == 'finished') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => GameResultsScreen(
                    gameSession: state.gameSession,
                    currentUserId: currentUserId,
                  ),
                ),
              );
            }
            if (state.animationDetails != null) {
              _gameBoardKey.currentState?.animateTurn(state.animationDetails!);
            }
          }
        },
        builder: (context, state) {
          if (state is! GameLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final game = state.gameSession;
          final opponentId =
          game.playerIds.firstWhere((id) => id != currentUserId, orElse: () => '');
          final myPerks = game.equippedPerks[currentUserId] ?? [];
          final myBooster = BoosterType.values
              .byName(game.equippedBoosters[currentUserId] ?? 'bomb');
          final opponentBooster = BoosterType.values
              .byName(game.equippedBoosters[opponentId] ?? 'bomb');

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  _PlayerInfoBar(
                    name: game.playerNames[opponentId] ?? 'Opponent',
                    photoUrl: game.playerPhotoUrls[opponentId] ?? '',
                    score: game.scores[opponentId] ?? 0,
                    roundWins: game.roundWins[opponentId] ?? 0,
                  ),
                  _BoosterChargeBar(
                    charge: game.boosterCharges[opponentId] ?? 0,
                    required: boosterRequirements[opponentBooster] ?? 7,
                    isOpponent: true,
                    boosterType: opponentBooster,
                  ),
                  const SizedBox(height: 8),
                  _TurnIndicator(
                    isMyTurn: state.isMyTurn,
                    turnEndsAt: game.turnEndsAt,
                    movesLeft: game.movesLeftInTurn,
                    isPaused: state.isTimerPaused,
                    key: ValueKey(game.turnEndsAt),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _GameBoard(
                      key: _gameBoardKey,
                      board: game.board,
                      isMyTurn: state.isMyTurn,
                      isHammerActive: state.isHammerActive,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _BoosterChargeBar(
                    charge: game.boosterCharges[currentUserId] ?? 0,
                    required: boosterRequirements[myBooster] ?? 7,
                    isOpponent: false,
                    boosterType: myBooster,
                  ),
                  _BoosterAndPerkBar(
                    boosterType: myBooster,
                    boosterCharge: game.boosterCharges[currentUserId] ?? 0,
                    perks: myPerks.map((p) => PerkType.values.byName(p)).toList(),
                    usedPerks: (game.usedPerks[currentUserId] ?? [])
                        .map((p) => PerkType.values.byName(p))
                        .toList(),
                    isMyTurn: state.isMyTurn,
                    isHammerActive: state.isHammerActive,
                  ),
                  _PlayerInfoBar(
                    name: game.playerNames[currentUserId] ?? 'You',
                    photoUrl: game.playerPhotoUrls[currentUserId] ?? '',
                    score: game.scores[currentUserId] ?? 0,
                    roundWins: game.roundWins[currentUserId] ?? 0,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GameBoard extends StatefulWidget {
  final List<List<GameTile>> board;
  final bool isMyTurn;
  final bool isHammerActive;

  const _GameBoard({
    super.key,
    required this.board,
    required this.isMyTurn,
    required this.isHammerActive,
  });

  @override
  State<_GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<_GameBoard> {
  List<List<GameTile>> _displayBoard = [];
  final GlobalKey<SpecialEffectsOverlayState> _effectsKey = GlobalKey();
  double _gemSize = 0;
  bool _isAnimating = false;

  Point<int>? _dragStartPoint;
  Point<int>? _dragEndPoint;
  Offset _dragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _displayBoard = widget.board.map((row) => List<GameTile>.from(row)).toList();
  }

  @override
  void didUpdateWidget(covariant _GameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isAnimating) {
      _displayBoard = widget.board.map((row) => List<GameTile>.from(row)).toList();
    }
  }

  void _onPanStart(DragStartDetails details, BuildContext context) {
    if (_isAnimating || !widget.isMyTurn) return;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final int x = (localPosition.dx / _gemSize).floor();
    final int y = (localPosition.dy / _gemSize).floor();
    if (x >= 0 && x < boardSize && y >= 0 && y < boardSize) {
      setState(() {
        _dragStartPoint = Point(x, y);
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragStartPoint == null) return;
    setState(() {
      _dragOffset += details.delta;
      final int dragX = (_dragOffset.dx / _gemSize).round();
      final int dragY = (_dragOffset.dy / _gemSize).round();

      if (dragX.abs() + dragY.abs() >= 1) {
        int endX = _dragStartPoint!.x + dragX;
        int endY = _dragStartPoint!.y + dragY;

        if (dragX.abs() > dragY.abs()) endY = _dragStartPoint!.y;
        else endX = _dragStartPoint!.x;

        endX = endX.clamp(0, boardSize - 1);
        endY = endY.clamp(0, boardSize - 1);

        if (endX != _dragStartPoint!.x || endY != _dragStartPoint!.y) {
          _dragEndPoint = Point(endX, endY);
        } else {
          _dragEndPoint = null;
        }
      } else {
        _dragEndPoint = null;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragStartPoint != null && _dragEndPoint != null) {
      context.read<GameBloc>().add(SwapGems(from: _dragStartPoint!, to: _dragEndPoint!));
    }
    setState(() {
      _dragStartPoint = null;
      _dragEndPoint = null;
      _dragOffset = Offset.zero;
    });
  }

  Future<void> animateTurn(AnimationDetails details) async {
    if (!mounted) return;
    setState(() => _isAnimating = true);

    var tempBoard = widget.board.map((row) => List<GameTile>.from(row)).toList();

    if (details.specialEffect == AnimationEffect.invalidSwap) {
      setState(() {
        _dragStartPoint = details.swapFrom;
        _dragEndPoint = details.swapTo;
      });
      await Future.delayed(const Duration(milliseconds: 250));
      setState(() {
        _dragStartPoint = null;
        _dragEndPoint = null;
      });
      await Future.delayed(const Duration(milliseconds: 250));
    }

    if(details.specialEffect != null && details.specialEffectOrigin != null) {
      _effectsKey.currentState?.playEffect(
          details.specialEffect!,
          details.specialEffectOrigin!,
          targets: details.specialEffectTargets,
          gemSize: _gemSize
      );
      if(details.specialEffect == AnimationEffect.lightning) await Future.delayed(const Duration(milliseconds: 400));
      else await Future.delayed(const Duration(milliseconds: 250));
    }

    for (final wave in details.clearedGems) {
      if (!mounted) return;

      for (final point in wave) {
        final gem = tempBoard[point.y][point.x];
        _effectsKey.currentState?.playScore(10, point, _gemSize);
      }
      _effectsKey.currentState?.playEffect(AnimationEffect.bomb, wave.first, gemSize: _gemSize * wave.length * 0.5);

      var newBoard = tempBoard.map((row) => List<GameTile>.from(row)).toList();
      _clearGems(newBoard, wave);

      setState(() => _displayBoard = newBoard);
      tempBoard = newBoard;
      await Future.delayed(const Duration(milliseconds: 450));
    }

    for(final entry in details.newGems.entries) {
      _effectsKey.currentState?.playEffect(AnimationEffect.creation, entry.key, gemSize: _gemSize);
    }
    await Future.delayed(const Duration(milliseconds: 200));

    if(mounted) {
      setState(() {
        _displayBoard = details.finalBoard;
      });
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isAnimating = false);
  }
  void _clearGems(List<List<GameTile>> board, Set<Point<int>> matches) {
    for (var point in matches) {
      board[point.y][point.x] = GameTile(color: GemType.empty.index, id: board[point.y][point.x].id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _gemSize = (constraints.maxWidth - 2) / boardSize;

      return GestureDetector(
        onPanStart: (details) => _onPanStart(details, context),
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: SpecialEffectsOverlay(
          key: _effectsKey,
          child: Container(
            padding: const EdgeInsets.all(1.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: List.generate(boardSize * boardSize, (index) {
                final x = index % boardSize;
                final y = index ~/ boardSize;
                final point = Point(x,y);

                GameTile tile = _displayBoard[y][x];
                Offset position = Offset(x * _gemSize, y * _gemSize);

                if (_dragStartPoint == point && _dragEndPoint != null) {
                  final dragEndPointPos = Offset(_dragEndPoint!.x * _gemSize, _dragEndPoint!.y * _gemSize);
                  position = Offset.lerp(position, dragEndPointPos, _dragOffset.distance / _gemSize)!;
                } else if (_dragEndPoint == point && _dragStartPoint != null) {
                  final dragStartPointPos = Offset(_dragStartPoint!.x * _gemSize, _dragStartPoint!.y * _gemSize);
                  position = Offset.lerp(position, dragStartPointPos, _dragOffset.distance / _gemSize)!;
                }

                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  left: position.dx,
                  top: position.dy,
                  child: _GemWidget(
                    key: ValueKey(tile.id),
                    tile: tile,
                    size: _gemSize,
                    isHammerActive: widget.isHammerActive,
                    onTap: () {
                      if (_isAnimating || !widget.isMyTurn) return;
                      if (widget.isHammerActive) {
                        context.read<GameBloc>().add(UseHammerOnGem(target: point));
                      }
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      );
    });
  }
}

class _GemWidget extends StatelessWidget {
  final GameTile tile;
  final double size;
  final bool isHammerActive;
  final VoidCallback onTap;

  const _GemWidget({
    super.key,
    required this.tile,
    required this.size,
    required this.isHammerActive,
    required this.onTap,
  });

  IconData _getIconForGem(int colorIndex) {
    if(colorIndex >= GemType.values.length) return Icons.error;
    switch (GemType.values[colorIndex]) {
      case GemType.blue: return Icons.arrow_drop_down;
      case GemType.green: return Icons.square_rounded;
      case GemType.purple: return Icons.hexagon_rounded;
      case GemType.red: return Icons.circle;
      case GemType.yellow: return Icons.change_history_rounded;
      case GemType.star: return Icons.star;
      default: return Icons.check_box_outline_blank;
    }
  }

  Color _getColorForGem(int colorIndex) {
    if(colorIndex >= GemType.values.length) return Colors.grey;
    switch (GemType.values[colorIndex]) {
      case GemType.blue: return Colors.orangeAccent;
      case GemType.green: return Colors.greenAccent;
      case GemType.purple: return Colors.deepPurpleAccent;
      case GemType.red: return Colors.redAccent;
      case GemType.yellow: return Colors.yellowAccent;
      case GemType.star: return Colors.lightBlueAccent;
      default: return Colors.transparent;
    }
  }

  Widget _getSpecialIcon(int specialIndex) {
    final iconSize = size * 0.7;
    if(specialIndex >= SpecialType.values.length) return const SizedBox.shrink();
    switch (SpecialType.values[specialIndex]) {
      case SpecialType.arrow_h: return Icon(Icons.arrow_forward_rounded, color: Colors.white, size: iconSize);
      case SpecialType.arrow_v: return Icon(Icons.arrow_upward_rounded, color: Colors.white, size: iconSize);
      case SpecialType.bomb: return Icon(Icons.brightness_7_rounded, color: Colors.white, size: iconSize);
      case SpecialType.lightning: return Icon(Icons.flash_on_rounded, color: Colors.white, size: iconSize);
      default: return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final game = (context.read<GameBloc>().state as GameLoaded).gameSession;

    int colorIndex = tile.color;
    final bool isPlayer2 = game.playerIds.length > 1 && currentUserId == game.playerIds[1];

    if (isPlayer2) {
      if (colorIndex == GemType.star.index) {
        colorIndex = GemType.red.index;
      } else if (colorIndex == GemType.red.index) {
        colorIndex = GemType.star.index;
      }
    }

    final color = _getColorForGem(colorIndex);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: tile.color != GemType.empty.index ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(2.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: color.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8.0),
              border: isHammerActive ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(_getIconForGem(colorIndex), color: color, size: size * 0.8),
                _getSpecialIcon(tile.special),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerInfoBar extends StatelessWidget {
  final String name;
  final String photoUrl;
  final int score;
  final int roundWins;

  const _PlayerInfoBar({
    required this.name,
    required this.photoUrl,
    required this.score,
    required this.roundWins,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 25,
          backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
          child: photoUrl.isEmpty ? Text(name[0]) : null,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Row(
              children: List.generate(totalRounds, (index) =>
                  Icon(
                    index < roundWins ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 18,
                  )
              ),
            ),
          ],
        ),
        const Spacer(),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: (score-100).toDouble().clamp(0, double.infinity), end: score.toDouble()),
          duration: const Duration(milliseconds: 500),
          builder: (context, value, child) {
            return Text(
              value.toInt().toString(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold),
            );
          },
        ),
      ],
    );
  }
}

class _BoosterChargeBar extends StatelessWidget {
  final int charge;
  final int required;
  final bool isOpponent;
  final BoosterType boosterType;

  const _BoosterChargeBar({required this.charge, required this.required, required this.isOpponent, required this.boosterType});

  IconData _getIcon() {
    switch (boosterType) {
      case BoosterType.bomb: return Icons.brightness_7_rounded;
      case BoosterType.arrow: return Icons.open_with;
      case BoosterType.hammer: return Icons.gavel;
      case BoosterType.shuffle: return Icons.shuffle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final game = (context.read<GameBloc>().state as GameLoaded).gameSession;
    Color color = Colors.grey;
    if(game.playerIds.isNotEmpty) {
      color = (currentUserId == game.playerIds.first) != isOpponent ? Colors.blue : Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.black.withOpacity(0.5), radius: 20, child: Icon(_getIcon(), color: Colors.white)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (charge / required).clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: Colors.black.withOpacity(0.5),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text("$charge/$required", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _TurnIndicator extends StatefulWidget {
  final bool isMyTurn;
  final DateTime turnEndsAt;
  final int movesLeft;
  final bool isPaused;

  const _TurnIndicator(
      {required this.isMyTurn,
        required this.turnEndsAt,
        required this.movesLeft,
        required this.isPaused,
        super.key});

  @override
  State<_TurnIndicator> createState() => _TurnIndicatorState();
}

class _TurnIndicatorState extends State<_TurnIndicator> {
  Timer? _timer;
  double _progress = 1.0;
  Duration _remaining = const Duration(seconds: 20);
  final Duration _totalDuration = const Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _TurnIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.turnEndsAt != oldWidget.turnEndsAt) {
      _startTimer();
    }
    if(widget.isPaused && _timer?.isActive == true) {
      _timer?.cancel();
    } else if (!widget.isPaused && _timer?.isActive != true) {
      _resumeTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _updateProgress();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _updateProgress();
    });
  }

  void _resumeTimer() {
    final newTurnEndsAt = DateTime.now().add(_remaining);
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final remaining = newTurnEndsAt.difference(DateTime.now());
      if(mounted) {
        setState(() {
          _remaining = remaining;
          _progress = remaining.inMilliseconds / _totalDuration.inMilliseconds;
          if (_progress <= 0) {
            _progress = 0;
            timer.cancel();
            if(widget.isMyTurn) {
              context.read<GameBloc>().add(EndTurnByTimer());
            }
          }
        });
      }
    });
  }

  void _updateProgress() {
    final remaining = widget.turnEndsAt.difference(DateTime.now());
    if (mounted) {
      setState(() {
        _remaining = remaining;
        _progress = remaining.inMilliseconds / _totalDuration.inMilliseconds;
        if (_progress <= 0) {
          _progress = 0;
          _timer?.cancel();
          if (widget.isMyTurn) {
            context.read<GameBloc>().add(EndTurnByTimer());
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isMyTurn ? "Your Turn" : "Opponent's Turn",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                "Moves: ${widget.movesLeft}",
                style: const TextStyle(color: Colors.white70),
              )
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.grey.shade700,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _BoosterAndPerkBar extends StatelessWidget {
  final BoosterType boosterType;
  final int boosterCharge;
  final List<PerkType> perks;
  final List<PerkType> usedPerks;
  final bool isMyTurn;
  final bool isHammerActive;

  const _BoosterAndPerkBar({
    required this.boosterType,
    required this.boosterCharge,
    required this.perks,
    required this.usedPerks,
    required this.isMyTurn,
    required this.isHammerActive,
  });

  @override
  Widget build(BuildContext context) {
    final requirement = boosterRequirements[boosterType] ?? 7;
    final isBoosterReady = boosterCharge >= requirement;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _PerkButton(
            perkType: perks.isNotEmpty ? perks[0] : PerkType.extraMove,
            isUsed: usedPerks.contains(perks.isNotEmpty ? perks[0] : null),
            isEnabled: isMyTurn && !isHammerActive,
          ),
          _BoosterButton(
            boosterType: boosterType,
            isEnabled: isMyTurn && isBoosterReady && !isHammerActive,
          ),
          _PerkButton(
            perkType: perks.length > 1 ? perks[1] : PerkType.colorSplash,
            isUsed: usedPerks.contains(perks.length > 1 ? perks[1] : null),
            isEnabled: isMyTurn && !isHammerActive,
          ),
        ],
      ),
    );
  }
}

class _BoosterButton extends StatelessWidget {
  final BoosterType boosterType;
  final bool isEnabled;
  const _BoosterButton({required this.boosterType, required this.isEnabled});

  IconData _getIcon() {
    switch (boosterType) {
      case BoosterType.bomb: return Icons.brightness_7_rounded;
      case BoosterType.arrow: return Icons.open_with;
      case BoosterType.hammer: return Icons.gavel;
      case BoosterType.shuffle: return Icons.shuffle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? () => context.read<GameBloc>().add(ActivateBooster()) : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SonarPulseTheme.appLinearGradient,
          ),
          child: Icon(_getIcon(), color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

class _PerkButton extends StatelessWidget {
  final PerkType perkType;
  final bool isUsed;
  final bool isEnabled;

  const _PerkButton(
      {required this.perkType, required this.isUsed, required this.isEnabled});

  IconData _getIcon() {
    switch (perkType) {
      case PerkType.extraMove: return Icons.add;
      case PerkType.colorSplash: return Icons.color_lens;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled && !isUsed
          ? () => context.read<GameBloc>().add(ActivatePerk(perkType))
          : null,
      child: Opacity(
        opacity: isEnabled && !isUsed ? 1.0 : 0.4,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.deepPurple,
            border: Border.all(color: Colors.purpleAccent, width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(_getIcon(), color: Colors.white),
              if (isUsed)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: const Icon(Icons.close, color: Colors.red),
                )
            ],
          ),
        ),
      ),
    );
  }
}