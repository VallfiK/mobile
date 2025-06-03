import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cottage.dart';
import '../services/cottage_service.dart';

class CottageDialog extends StatefulWidget {
  final Cottage? cottage;
  final Function(BuildContext, String, String, double, List<String>, int) onSave;

  const CottageDialog({
    super.key,
    this.cottage,
    required this.onSave,
  });

  @override
  State<CottageDialog> createState() => _CottageDialogState();
}

class _CottageDialogState extends State<CottageDialog> {
  late TextEditingController nameController;
  late TextEditingController descriptionController;
  late TextEditingController priceController;
  late TextEditingController capacityController;
  late TextEditingController imageUrlController;
  late List<String> images;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.cottage?.name ?? '');
    descriptionController = TextEditingController(text: widget.cottage?.description ?? '');
    priceController = TextEditingController(text: widget.cottage?.price.toString() ?? '');
    capacityController = TextEditingController(text: widget.cottage?.capacity.toString() ?? '');
    imageUrlController = TextEditingController();
    images = widget.cottage?.images.toList() ?? [];
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.cottage == null ? 'Добавить домик' : 'Редактировать домик',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Описание',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Цена за сутки',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: capacityController,
                    decoration: const InputDecoration(
                      labelText: 'Вместимость',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: imageUrlController,
                          decoration: const InputDecoration(
                            labelText: 'URL изображения',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          if (imageUrlController.text.isNotEmpty) {
                            setState(() {
                              images.add(imageUrlController.text);
                              imageUrlController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (images.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Изображения:'),
                    const SizedBox(height: 8),
                    Container(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Image.network(
                                  images[index],
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 80,
                                      width: 80,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.error),
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      images.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final price = double.tryParse(priceController.text) ?? 0;
                    final capacity = int.tryParse(capacityController.text) ?? 1;
                    widget.onSave(
                      context,
                      nameController.text,
                      descriptionController.text,
                      price,
                      images,
                      capacity,
                    );
                    Navigator.of(context).pop();
                  },
                  child: Text(widget.cottage == null ? 'Добавить' : 'Сохранить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CottageManagementTab extends StatefulWidget {
  const CottageManagementTab({super.key});

  @override
  State<CottageManagementTab> createState() => _CottageManagementTabState();
}

class _CottageManagementTabState extends State<CottageManagementTab> {
  late Future<List<Cottage>> _cottagesFuture;

  @override
  void initState() {
    super.initState();
    _loadCottages();
  }

  void _loadCottages() {
    _cottagesFuture = Provider.of<CottageService>(context, listen: false).getCottages();
  }

  Future<void> _showCottageDialog([Cottage? cottage]) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => CottageDialog(
        cottage: cottage,
        onSave: (BuildContext context, String name, String description, double price, List<String> images, int capacity) async {
          try {
            final cottageService = Provider.of<CottageService>(context, listen: false);

            final updatedCottage = Cottage(
              id: cottage?.id ?? '',
              name: name,
              description: description,
              price: price,
              images: images,
              capacity: capacity,
            );

            if (cottage == null) {
              await cottageService.createCottage(updatedCottage);
            } else {
              await cottageService.updateCottage(updatedCottage);
            }

            setState(() {
              _loadCottages();
            });
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка: $e')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Cottage>>(
      future: _cottagesFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Cottage>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }

        final cottages = snapshot.data ?? [];

        return Stack(
          children: [
            ListView.builder(
              itemCount: cottages.length,
              padding: const EdgeInsets.only(bottom: 80),
              itemBuilder: (BuildContext context, int index) {
                final cottage = cottages[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cottage.images.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: PageView.builder(
                            itemCount: cottage.images.length,
                            itemBuilder: (BuildContext context, int imageIndex) {
                              return Image.network(
                                cottage.images[imageIndex],
                                fit: BoxFit.cover,
                                errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.error, size: 64),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ListTile(
                        title: Text(cottage.name),
                        subtitle: Text(cottage.description),
                        trailing: Text('${cottage.price.toStringAsFixed(2)} ₽/сутки'),
                      ),
                      ButtonBar(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Редактировать'),
                            onPressed: () {
                              _showCottageDialog(cottage);
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text('Удалить', style: TextStyle(color: Colors.red)),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext dialogContext) => AlertDialog(
                                  title: const Text('Подтверждение'),
                                  content: const Text('Вы уверены, что хотите удалить этот домик?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop<bool>(false);
                                      },
                                      child: const Text('Отмена'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop<bool>(true);
                                      },
                                      child: const Text('Удалить'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                try {
                                  await Provider.of<CottageService>(context, listen: false)
                                      .deleteCottage(cottage.id);
                                  setState(() {
                                    _loadCottages();
                                  });
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Ошибка: $e')),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () {
                  _showCottageDialog(null);
                },
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }
} 