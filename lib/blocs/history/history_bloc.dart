import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/locator.dart';
import 'package:freegram/models/match_history_model.dart';
import 'package:freegram/repositories/match_history_repository.dart';

// Events
abstract class HistoryEvent {}

class LoadHistory extends HistoryEvent {}

class ClearHistory extends HistoryEvent {}

// States
abstract class HistoryState {}

class HistoryLoading extends HistoryState {}

class HistoryLoaded extends HistoryState {
  final List<MatchHistoryModel> matches;
  HistoryLoaded(this.matches);
}

class HistoryError extends HistoryState {
  final String message;
  HistoryError(this.message);
}

// Bloc
class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final MatchHistoryRepository _repository = locator<MatchHistoryRepository>();

  HistoryBloc() : super(HistoryLoading()) {
    on<LoadHistory>((event, emit) async {
      emit(HistoryLoading());
      try {
        await _repository.init(); // Ensure box is open
        final matches = _repository.getHistory();
        emit(HistoryLoaded(matches));
      } catch (e) {
        emit(HistoryError("Failed to load history: $e"));
      }
    });

    on<ClearHistory>((event, emit) async {
      await _repository.clearHistory();
      add(LoadHistory());
    });
  }
}
