part of 'inventory_bloc.dart';

@immutable
abstract class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object> get props => [];
}

/// Fetches the user's inventory items and their definitions.
class LoadInventory extends InventoryEvent {}

/// Internal event to push updated inventory data to the state.
class _InventoryUpdated extends InventoryEvent {
  final List<InventoryItem> inventoryItems;
  final Map<String, ItemDefinition> itemDefinitions;

  const _InventoryUpdated({
    required this.inventoryItems,
    required this.itemDefinitions,
  });

  @override
  List<Object> get props => [inventoryItems, itemDefinitions];
}
