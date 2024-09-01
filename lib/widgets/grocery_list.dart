import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shopping_list/data/categories.dart';
import 'package:shopping_list/models/grocery_item.dart';
import 'package:shopping_list/widgets/new_item.dart';

class GroceryList extends StatefulWidget {
  const GroceryList({super.key});

  @override
  State<GroceryList> createState() => _GroceryListState();
}

class _GroceryListState extends State<GroceryList> {
  List<GroceryItem> _groceryItems = [];
  var _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() async {
    final url = Uri.https('shopping-list-1988a-default-rtdb.firebaseio.com',
        'shopping-list.json');
    try {
      final response = await http.get(url);
      if (response.statusCode >= 400) {
        setState(() {
          _error = 'Failed to fetch data. Please try again later.';
        });
      }
      if (response.body == 'null') {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final Map<String, dynamic> listData = json.decode(response.body);
      final List<GroceryItem> loadedItems = [];
      for (final item in listData.entries) {
        final category = categories.entries
            .firstWhere((categoryItem) =>
                categoryItem.value.title == item.value['category'])
            .value;
        loadedItems.add(
          GroceryItem(
            id: item.key,
            name: item.value['name'],
            quantity: item.value['quantity'],
            category: category,
          ),
        );
      }
      setState(() {
        _groceryItems = loadedItems;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = 'Please check your internet connection or try again later.';
      });
    }
  }

  void _addItem() async {
    final newItem = await Navigator.of(context).push<GroceryItem>(
      MaterialPageRoute(builder: (ctx) => const NewItem()),
    );
    if (newItem == null) return;
    setState(() {
      _groceryItems.add(newItem);
    });
  }

  void _reAddDeletion(GroceryItem item, itemIndex) async {
    final urlAdd = Uri.https('shopping-list-1988a-default-rtdb.firebaseio.com',
        'shopping-list.json');
    final response = await http.post(
      urlAdd,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(
        {
          'name': item.name,
          'quantity': item.quantity,
          'category': item.category.title,
        },
      ),
    );

    final Map<String, dynamic> resData = json.decode(response.body);
    setState(() {
      _groceryItems.insert(
        itemIndex,
        GroceryItem(
            id: resData['name'],
            name: item.name,
            quantity: item.quantity,
            category: item.category),
      );
    });
  }

  void _removeItem(GroceryItem item) async {
    final url = Uri.https('shopping-list-1988a-default-rtdb.firebaseio.com',
        'shopping-list/${item.id}.json');
    final itemIndex = _groceryItems.indexOf(item);
    setState(() {
      _groceryItems.remove(item);
    });
    final response = await http.delete(url);
    if (response.statusCode >= 400) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        duration: Duration(seconds: 3),
        content: Text("Failed to delete the item."),
      ));
      _reAddDeletion(item, itemIndex);
    } else {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: const Text("Item Deleted."),
          action: SnackBarAction(
              label: "Undo",
              onPressed: () async {
                _reAddDeletion(item, itemIndex);
              }),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = const Center(child: Text("No items added yet."));

    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    }

    if (_groceryItems.isNotEmpty) {
      content = ListView.builder(
        itemCount: _groceryItems.length,
        itemBuilder: (ctx, index) => Dismissible(
          background: Container(
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withOpacity(0.75),
                borderRadius: BorderRadius.circular(15)),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.delete,
                  color: Colors.white,
                  size: 30,
                ),
                SizedBox(
                  width: 10,
                ),
                Text(
                  "Delete",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              ],
            ),
          ),
          onDismissed: (direction) {
            _removeItem(_groceryItems[index]);
          },
          key: ValueKey(_groceryItems[index].id),
          child: ListTile(
            title: Text(_groceryItems[index].name),
            leading: Container(
              width: 24,
              height: 24,
              color: _groceryItems[index].category.color,
            ),
            trailing: Text(
              _groceryItems[index].quantity.toString(),
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      content = Center(child: Text(_error!));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Groceries"),
        actions: [
          IconButton(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: content,
    );
  }
}
