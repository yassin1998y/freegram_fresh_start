import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:freegram/models/inventory_item.dart';
import 'package:freegram/models/item_definition.dart';
import 'package:freegram/repositories/inventory_repository.dart';
import 'package:meta/meta.dart';

part 'inventory_event.dart';
part 'inventory_state.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final InventoryRepository _inventoryRepository;
  final FirebaseAuth _firebaseAuth;
  StreamSubscription? _inventorySubscription;

  InventoryBloc({
    required InventoryRepository inventoryRepository,
    FirebaseAuth? firebaseAuth,
  })  : _inventoryRepository = inventoryRepository,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        super(InventoryInitial()) {
    on<LoadInventory>(_onLoadInventory);
    on<_InventoryUpdated>(_onInventoryUpdated);
  }

  /// Handles loading the user's inventory.
  /// It listens to a stream of inventory items and fetches their definitions.
  void _onLoadInventory(LoadInventory event, Emitter<InventoryState> emit) {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      emit(const InventoryError("User not authenticated."));
      return;
    }

    emit(InventoryLoading());
    _inventorySubscription?.cancel();
    _inventorySubscription =
        _inventoryRepository.getUserInventoryStream(user.uid).listen(
              (items) async {
            try {
              // For each item in the inventory, fetch its corresponding definition.
              // Using Future.wait for efficient, parallel fetching.
              final definitionFutures = items
                  .map((item) => _inventoryRepository.getItemDefinition(item.itemId))
                  .toList();
              final definitions = await Future.wait(definitionFutures);

              // Create a map for quick lookups in the UI (itemId -> ItemDefinition).
              final definitionMap = {
                for (var def in definitions) def.id: def,
              };

              add(_InventoryUpdated(
                inventoryItems: items,
                itemDefinitions: definitionMap,
              ));
            } catch (e) {
              emit(InventoryError(e.toString()));
            }
          },
          onError: (error) {
            emit(InventoryError(error.toString()));
          },
        );
  }

  /// Pushes the fully loaded and mapped inventory data to the UI.
  void _onInventoryUpdated(_InventoryUpdated event, Emitter<InventoryState> emit) {
    emit(InventoryLoaded(
      inventoryItems: event.inventoryItems,
      itemDefinitions: event.itemDefinitions,
    ));
  }

  @override
  Future<void> close() {
    _inventorySubscription?.cancel();
    return super.close();
  }
}
