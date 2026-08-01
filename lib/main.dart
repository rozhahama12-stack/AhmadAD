import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

void main() {
  runApp(const MaxiDesignApp());
}

class MaxiDesignApp extends StatelessWidget {
  const MaxiDesignApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Maxi Embroidery System',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const MaxiGalleryScreen(),
    );
  }
}

class MaxiItem {
  final String code;
  final String title;
  final String imagePath; // وێنەی سەرەکی (کەڤەر) لە گالەرییەوە
  final String dstFileName; // فایلی DST
  final String price;
  final String sleevePrice; // نرخی سەرقۆڵ
  final String designType;
  final String telegramLink;
  List<String> extraImages; // وێنە زیاترەکان کە لە گالەری زیاد دەکرێن

  MaxiItem({
    required this.code,
    required this.title,
    required this.imagePath,
    required this.dstFileName,
    required this.price,
    required this.sleevePrice,
    required this.designType,
    required this.telegramLink,
    required this.extraImages,
  });
}

class MaxiGalleryScreen extends StatefulWidget {
  const MaxiGalleryScreen({super.key});

  @override
  State<MaxiGalleryScreen> createState() => _MaxiGalleryScreenState();
}

class _MaxiGalleryScreenState extends State<MaxiGalleryScreen> {
  final List<MaxiItem> _allMaxis = [];
  List<MaxiItem> _filteredMaxis = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredMaxis = _allMaxis;
  }

  void _runSearch(String keyword) {
    setState(() {
      if (keyword.isEmpty) {
        _filteredMaxis = _allMaxis;
      } else {
        _filteredMaxis = _allMaxis
            .where((item) =>
                item.code.toLowerCase().contains(keyword.toLowerCase()) ||
                item.title.toLowerCase().contains(keyword.toLowerCase()) ||
                item.designType.toLowerCase().contains(keyword.toLowerCase()))
            .toList();
      }
    });
  }

  String _generateNewCode() {
    int nextNumber = _allMaxis.length + 1;
    return 'A-$nextNumber';
  }

  // کردنەوەی گالەری بۆ هەڵبژاردنی وێنە
  Future<String?> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    return image?.path;
  }

  // کردنەوەی فایل مەنەجەر بۆ هەڵبژاردنی فایلی DST
  Future<String?> _pickDstFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result != null) {
      return result.files.single.name;
    }
    return null;
  }

  void _showAddDialog() {
    final String generatedCode = _generateNewCode();
    final titleController = TextEditingController();
    final priceController = TextEditingController();
    final sleevePriceController = TextEditingController();
    final telegramController = TextEditingController();
    
    String? selectedImagePath;
    String? selectedDstFile;
    String selectedType = 'بەژنە';

    final List<String> types = [
      'بەژنە',
      'نیو بەژنە',
      'سنگی بچوک',
      'سنگی گوڵدار',
      'دیزاینی گوڵی گەورە',
      'مغاویری',
      'نەخشی ئەتەمین',
      'نەخشی قەیتانە',
      'نەخشی کریستال'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text('زیادکردنی دیزاینی مەکسی نوێ'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'کۆدی نەخشە: $generatedCode',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'ناوی دیزاین'),
                    ),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'نرخی سەرەکی دیزاین'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: sleevePriceController,
                      decoration: const InputDecoration(labelText: 'نرخی سەرقۆڵ'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: telegramController,
                      decoration: const InputDecoration(labelText: 'لینکی دیزاین (تێلیگرام)'),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () async {
                        String? path = await _pickImageFromGallery();
                        if (path != null) {
                          dialogSetState(() {
                            selectedImagePath = path;
                          });
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: Text(selectedImagePath == null ? 'هەڵبژاردنی وێنەی کەڤەر لە گالەری' : 'وێنە هەڵبژێردرا ✅'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        String? fileName = await _pickDstFile();
                        if (fileName != null) {
                          dialogSetState(() {
                            selectedDstFile = fileName;
                          });
                        }
                      },
                      icon: const Icon(Icons.insert_drive_file),
                      label: Text(selectedDstFile == null ? 'هەڵبژاردنی فایلی نەخش (DST)' : 'فایل هەڵبژێردرا: $selectedDstFile'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => dialogSetState(() => selectedType = val!),
                      decoration: const InputDecoration(labelText: 'جۆری دیزاین'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('پاشگەزبوونەوە'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty && selectedImagePath != null) {
                      setState(() {
                        _allMaxis.add(MaxiItem(
                          code: generatedCode,
                          title: titleController.text,
                          imagePath: selectedImagePath!,
                          dstFileName: selectedDstFile ?? '${generatedCode}.dst',
                          price: priceController.text.isNotEmpty ? priceController.text : '0',
                          sleevePrice: sleevePriceController.text.isNotEmpty ? sleevePriceController.text : '0',
                          designType: selectedType,
                          telegramLink: telegramController.text,
                          extraImages: [],
                        ));
                        _filteredMaxis = _allMaxis;
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('زیادکردن'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سیستەمی گەڕانی دیزاینی مەکسی'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _runSearch,
              decoration: InputDecoration(
                hintText: 'گەڕان بەدوای کۆد، ناو یان جۆر...',
                prefixIcon: const Icon(Icons.search, color: Colors.pink),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _filteredMaxis.isNotEmpty
                  ? GridView.builder(
                      itemCount: _filteredMaxis.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.7,
                      ),
                      itemBuilder: (context, index) {
                        final maxi = _filteredMaxis[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MaxiDetailScreen(
                                  maxiItem: maxi,
                                  onUpdate: () => setState(() {}),
                                ),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(15),
                                    ),
                                    child: Image.file(
                                      File(maxi.imagePath),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        maxi.code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.pink,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        maxi.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('\$${maxi.price}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                          Text(maxi.designType, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Text('هیچ دیزاینێک نەدۆزراوەتەوە!'),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: Colors.pink,
        icon: const Icon(Icons.add),
        label: const Text('زیادکردنی دیزاین'),
      ),
    );
  }
}

// شاشەی وردەکارییەکان
class MaxiDetailScreen extends StatefulWidget {
  const MaxiDetailScreen({super.key, required this.maxiItem, required this.onUpdate});

  final MaxiItem maxiItem;
  final VoidCallback onUpdate;

  @override
  State<MaxiDetailScreen> createState() => _MaxiDetailScreenState();
}

class _MaxiDetailScreenState extends State<MaxiDetailScreen> {
  
  // زیادکردنی وێنەی زیاتر لە گالەرییەوە
  Future<void> _addExtraImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        widget.maxiItem.extraImages.add(image.path);
      });
      widget.onUpdate();
    }
  }

  // پیشاندانی وێنە بە گەورەیی کاتێک دەپەنجە دەنێیت بەسەریدا
  void _showFullscreenImage(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.file(File(imagePath)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('کۆد: ${widget.maxiItem.code}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // وێنەی سەرەکی کەڤەر (بە گەورەکردن)
            Center(
              child: GestureDetector(
                onTap: () => _showFullscreenImage(widget.maxiItem.imagePath),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(
                    File(widget.maxiItem.imagePath),
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              widget.maxiItem.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('نرخی سەرەکی: \$${widget.maxiItem.price}', style: const TextStyle(fontSize: 15, color: Colors.green, fontWeight: FontWeight.bold)),
                Text('نرخی سەرقۆڵ: \$${widget.maxiItem.sleevePrice}', style: const TextStyle(fontSize: 15, color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text('جۆر: ${widget.maxiItem.designType}'),
                  backgroundColor: Colors.pink[100],
                ),
                if (widget.maxiItem.telegramLink.isNotEmpty)
                  Text(
                    'لینکی دیزاین: تێلیگرام',
                    style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline, fontSize: 13),
                  ),
              ],
            ),
            const Divider(height: 30),
            // فایلی DST
            const Text(
              'فایلی دیزاینی DST:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.maxiItem.dstFileName,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('داگرتن'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // بەشی وێنەی زیاتر بە شێوازی ئاسۆیی و دوگمەی زیادکردن
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'وێنەی زیاتر:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _addExtraImage,
                  icon: const Icon(Icons.add_photo_alternate, size: 18),
                  label: const Text('زیادکردنی وێنە'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 130,
              child: widget.maxiItem.extraImages.isNotEmpty
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.maxiItem.extraImages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => _showFullscreenImage(widget.maxiItem.extraImages[index]),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(widget.maxiItem.extraImages[index]),
                                width: 110,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Text('هیچ وێنەیەکی زیاتر نییە، لە دوگمەی سەرەوە زیاد بکە.'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
