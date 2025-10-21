part of 'inventory_bloc.dart';

@immutable
abstract class InventoryState extends Equatable {
  const InventoryState();

  @override
  List<Object> get props => [];
}

/// The initial state before inventory is loaded.
class InventoryInitial extends InventoryState {}

/// The state when inventory is being fetched.
class InventoryLoading extends InventoryState {}

/// The state when inventory has been successfully loaded.
class InventoryLoaded extends InventoryState {
  /// The list of items the user actually owns.
  final List<InventoryItem> inventoryItems;

  /// A map linking item IDs to their master definitions for easy data lookup.
  final Map<String, ItemDefinition> itemDefinitions;

  const InventoryLoaded({
    required this.inventoryItems,
    required this.itemDefinitions,
  });

  @override
  List<Object> get props => [inventoryItems, itemDefinitions];
}

/// The state when an error occurs while fetching the inventory.
class InventoryError extends InventoryState {
  final String message;

  const InventoryError(this.message);

  @override
  List<Object> get props => [message];
}
