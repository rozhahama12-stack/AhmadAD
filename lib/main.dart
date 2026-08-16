import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'firebase_options.dart';
import 'package:universal_html/html.dart' as html;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
  final String id;
  final int codeNumber; 
  final String title;
  final Uint8List imageBytes;
  List<String> dstFileNames;
  final String price;
  final String sleevePrice;
  final String dstPrice; // نرخی فایلی DST بە دینار
  final String neckType;    
  final String designStyle; 
  final String accessType;  
  final String telegramLink;
  final String unlockCode;  
  List<Uint8List> extraImagesBytes;
  final dynamic createdAt;

  MaxiItem({
    required this.id,
    required this.codeNumber,
    required this.title,
    required this.imageBytes,
    required this.dstFileNames,
    required this.price,
    required this.sleevePrice,
    required this.dstPrice,
    required this.neckType,
    required this.designStyle,
    required this.accessType,
    required this.telegramLink,
    required this.unlockCode,
    required this.extraImagesBytes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'codeNumber': codeNumber,
        'title': title,
        'imageBytes': base64Encode(imageBytes),
        'dstFileNames': dstFileNames,
        'price': price,
        'sleevePrice': sleevePrice,
        'dstPrice': dstPrice,
        'neckType': neckType,
        'designStyle': designStyle,
        'accessType': accessType,
        'telegramLink': telegramLink,
        'unlockCode': unlockCode,
        'extraImagesBytes': extraImagesBytes.map((img) => base64Encode(img)).toList(),
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      };

  factory MaxiItem.fromMap(String id, Map<String, dynamic> json) => MaxiItem(
        id: id,
        codeNumber: json['codeNumber'] ?? 1,
        title: json['title'] ?? '',
        imageBytes: base64Decode(json['imageBytes'] ?? ''),
        dstFileNames: List<String>.from(json['dstFileNames'] ?? []),
        price: json['price'] ?? '0',
        sleevePrice: json['sleevePrice'] ?? '0',
        dstPrice: json['dstPrice'] ?? '0',
        neckType: json['neckType'] ?? 'ملی خڕ',
        designStyle: json['designStyle'] ?? 'نیو بەژن',
        accessType: json['accessType'] ?? 'فری',
        telegramLink: json['telegramLink'] ?? '',
        unlockCode: json['unlockCode'] ?? 'MAXI-SECURE-KEY',
        extraImagesBytes: (json['extraImagesBytes'] as List? ?? [])
            .map((img) => base64Decode(img))
            .toList(),
        createdAt: json['createdAt'],
      );
}

class MaxiGalleryScreen extends StatefulWidget {
  const MaxiGalleryScreen({super.key});

  @override
  State<MaxiGalleryScreen> createState() => _MaxiGalleryScreenState();
}

class _MaxiGalleryScreenState extends State<MaxiGalleryScreen> {
  bool _isAdmin = true; 
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';
  String? _selectedAccessFilter; 
  String? _selectedNeckFilter;
  String? _selectedStyleFilter;

  final List<String> neckTypes = [
    'ملی حەوت',
    'ملی چوارگۆشە',
    'ملی خڕ',
    'دیزاینی بێ مل',
  ];

  final List<String> designStyles = [
    'دیزاینی نقێم',
    'نیو بەژن',
    'نەخشی گولدار',
    'نەخشی داو',
    'نەخشی کورت',
    'نەخشی درێژ',
    'نەخشی ئەتەمین',
    'نەخشی بەژن',
    'نەخشی قەیتان',
    'نەخشی گولی گەورە',
    'نەخشی گولی ورد',
  ];

  String _generateComplexCode(int codeNum) {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    Random rnd = Random();
    String part1 = String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    String part2 = String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    return 'MX-$codeNum-$part1-$part2';
  }

  Future<Uint8List?> _pickImageBytes() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      return await image.readAsBytes();
    }
    return null;
  }

  Future<List<String>> _pickMultipleDstFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (result != null) {
      return result.files.map((file) => file.name).toList();
    }
    return [];
  }

  Future<int> _getNextCodeNumber() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('maxi_designs')
        .orderBy('codeNumber', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return 1;
    }
    int lastCode = querySnapshot.docs.first.data()['codeNumber'] ?? 0;
    return lastCode + 1;
  }

  void _showAddDialog() async {
    int nextCode = await _getNextCodeNumber();
    String generatedKey = _generateComplexCode(nextCode);

    final titleController = TextEditingController();
    final priceController = TextEditingController();
    final sleevePriceController = TextEditingController();
    final dstPriceController = TextEditingController();
    final telegramController = TextEditingController();
    final unlockCodeController = TextEditingController(text: generatedKey);
    
    Uint8List? selectedImageBytes;
    List<String> selectedDstFiles = [];
    String selectedNeck = neckTypes.first;
    String selectedStyle = designStyles.first;
    String selectedAccess = 'فری';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text('زیادکردنی دیزاینی نوێ'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'دیزاین: A$nextCode',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'ناوی دیزاین'),
                    ),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'نرخی سەرەکی (بە دینار عێراقی)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: sleevePriceController,
                      decoration: const InputDecoration(labelText: 'نرخی سەرقۆڵ (بە دینار عێراقی)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: telegramController,
                      decoration: const InputDecoration(labelText: 'لینکی تێلیگرام'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedAccess,
                      items: const [
                        DropdownMenuItem(value: 'فری', child: Text('فری')),
                        DropdownMenuItem(value: 'تایبەت', child: Text('تایبەت (پێویستی بە کۆدی قوفڵە)')),
                      ],
                      onChanged: (val) => dialogSetState(() => selectedAccess = val!),
                      decoration: const InputDecoration(labelText: 'جۆری دەستگەیشتن'),
                    ),
                    if (selectedAccess == 'تایبەت') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: dstPriceController,
                        decoration: const InputDecoration(labelText: 'نرخی فایلی DST (بە دینار عێراقی)'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: unlockCodeController,
                        decoration: const InputDecoration(labelText: 'کۆدی قوفڵی ئاڵۆز (خۆکارانە دروستبووە)'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedNeck,
                      items: neckTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => dialogSetState(() => selectedNeck = val!),
                      decoration: const InputDecoration(labelText: 'جۆری مل'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedStyle,
                      items: designStyles.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => dialogSetState(() => selectedStyle = val!),
                      decoration: const InputDecoration(labelText: 'جۆری دیزاین / نەخشە'),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Uint8List? bytes = await _pickImageBytes();
                        if (bytes != null) {
                          dialogSetState(() {
                            selectedImageBytes = bytes;
                          });
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: Text(selectedImageBytes == null ? 'هەڵبژاردنی وێنەی کەڤەر' : 'وێنە هەڵبژێردرا ✅'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        List<String> files = await _pickMultipleDstFiles();
                        if (files.isNotEmpty) {
                          dialogSetState(() {
                            selectedDstFiles.addAll(files);
                          });
                        }
                      },
                      icon: const Icon(Icons.insert_drive_file),
                      label: Text(selectedDstFiles.isEmpty ? 'هەڵبژاردنی فایلی DST' : 'فایل هەڵبژێردرا (${selectedDstFiles.length})'),
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
                  onPressed: () async {
                    if (titleController.text.isNotEmpty && selectedImageBytes != null) {
                      final newItem = MaxiItem(
                        id: '',
                        codeNumber: nextCode,
                        title: titleController.text,
                        imageBytes: selectedImageBytes!,
                        dstFileNames: selectedDstFiles.isNotEmpty ? selectedDstFiles : ['design_A$nextCode.dst'],
                        price: priceController.text.isNotEmpty ? priceController.text : '0',
                        sleevePrice: sleevePriceController.text.isNotEmpty ? sleevePriceController.text : '0',
                        dstPrice: dstPriceController.text.isNotEmpty ? dstPriceController.text : '0',
                        neckType: selectedNeck,
                        designStyle: selectedStyle,
                        accessType: selectedAccess,
                        telegramLink: telegramController.text,
                        unlockCode: unlockCodeController.text.isNotEmpty ? unlockCodeController.text : generatedKey,
                        extraImagesBytes: [],
                        createdAt: FieldValue.serverTimestamp(),
                      );

                      await FirebaseFirestore.instance.collection('maxi_designs').add(newItem.toJson());
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('زیادکردن بۆ سێرڤەر'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editDesign(MaxiItem maxi) {
    final titleController = TextEditingController(text: maxi.title);
    final priceController = TextEditingController(text: maxi.price);
    final sleeveController = TextEditingController(text: maxi.sleevePrice);
    final dstPriceController = TextEditingController(text: maxi.dstPrice);
    final telegramController = TextEditingController(text: maxi.telegramLink);
    final unlockCodeController = TextEditingController(text: maxi.unlockCode);
    
    String selectedNeck = neckTypes.contains(maxi.neckType) ? maxi.neckType : neckTypes.first;
    String selectedStyle = designStyles.contains(maxi.designStyle) ? maxi.designStyle : designStyles.first;
    String selectedAccess = ['فری', 'تایبەت'].contains(maxi.accessType) ? maxi.accessType : 'فری';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            title: Text('دەستکاریکردنی دیزاین: A${maxi.codeNumber}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'ناوی دیزاین')),
                  TextField(controller: priceController, decoration: const InputDecoration(labelText: 'نرخی سەرەکی (دینار)'), keyboardType: TextInputType.number),
                  TextField(controller: sleeveController, decoration: const InputDecoration(labelText: 'نرخی سەرقۆڵ (دینار)'), keyboardType: TextInputType.number),
                  TextField(controller: telegramController, decoration: const InputDecoration(labelText: 'لینکی تێلیگرام')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedAccess,
                    items: const [
                      DropdownMenuItem(value: 'فری', child: Text('فری')),
                      DropdownMenuItem(value: 'تایبەت', child: Text('تایبەت')),
                    ],
                    onChanged: (val) => dialogSetState(() => selectedAccess = val!),
                    decoration: const InputDecoration(labelText: 'جۆری دەستگەیشتن'),
                  ),
                  if (selectedAccess == 'تایبەت') ...[
                    const SizedBox(height: 10),
                    TextField(controller: dstPriceController, decoration: const InputDecoration(labelText: 'نرخی فایلی DST (دینار)'), keyboardType: TextInputType.number),
                    const SizedBox(height: 10),
                    TextField(controller: unlockCodeController, decoration: const InputDecoration(labelText: 'کۆدی قوفڵی ئاڵۆز')),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedNeck,
                    items: neckTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) => dialogSetState(() => selectedNeck = val!),
                    decoration: const InputDecoration(labelText: 'جۆری مل'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedStyle,
                    items: designStyles.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) => dialogSetState(() => selectedStyle = val!),
                    decoration: const InputDecoration(labelText: 'جۆری دیزاین / نەخشە'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('پاشگەزبوونەوە')),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('maxi_designs').doc(maxi.id).update({
                    'title': titleController.text,
                    'price': priceController.text,
                    'sleevePrice': sleeveController.text,
                    'dstPrice': dstPriceController.text,
                    'telegramLink': telegramController.text,
                    'neckType': selectedNeck,
                    'designStyle': selectedStyle,
                    'accessType': selectedAccess,
                    'unlockCode': unlockCodeController.text,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('دیزاینەکە نوێکرایەوە ✅')));
                },
                child: const Text('پاشەکەوتکردن'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _deleteDesign(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سڕینەوەی دیزاین'),
        content: const Text('ئایا دڵنیای لە سڕینەوەی ئەم دیزاینە؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('نەخێر')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('maxi_designs').doc(id).delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('دیزاینەکە سڕایەوە 🗑️')));
            },
            child: const Text('بەڵێ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            automaticallyImplyLeading: false,
            floating: true,
            pinned: false,
            snap: true,
            backgroundColor: Colors.white,
            toolbarHeight: 65,
            title: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchKeyword = val.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'گەڕان بەدوای کۆد (A1)، ناو یان جۆر...',
                      prefixIcon: const Icon(Icons.search, color: Colors.pink),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_isAdmin ? Icons.admin_panel_settings : Icons.visibility, color: Colors.pink),
                  tooltip: 'گۆڕینی دۆخ',
                  onPressed: () {
                    setState(() {
                      _isAdmin = !_isAdmin;
                    });
                  },
                ),
              ],
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverFilterDelegate(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedAccessFilter,
                            hint: const Text('جۆر', style: TextStyle(fontSize: 11)),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('هەموو', style: TextStyle(fontSize: 11))),
                              const DropdownMenuItem(value: 'فری', child: Text('فری 🟢', style: TextStyle(fontSize: 11))),
                              const DropdownMenuItem(value: 'تایبەت', child: Text('تایبەت 🔒', style: TextStyle(fontSize: 11))),
                            ],
                            onChanged: (val) => setState(() => _selectedAccessFilter = val),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedNeckFilter,
                            hint: const Text('جۆری مل', style: TextStyle(fontSize: 11)),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('ملەکان', style: TextStyle(fontSize: 11))),
                              ...neckTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 11)))),
                            ],
                            onChanged: (val) => setState(() => _selectedNeckFilter = val),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedStyleFilter,
                            hint: const Text('نەخشە', style: TextStyle(fontSize: 11)),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('نەخشەکان', style: TextStyle(fontSize: 11))),
                              ...designStyles.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 11)))),
                            ],
                            onChanged: (val) => setState(() => _selectedStyleFilter = val),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('maxi_designs').orderBy('codeNumber', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('هیچ دیزاینێک لە سێرڤەردا نەدۆزراوەتەوە!'));
              }

              final docs = snapshot.data!.docs;
              List<MaxiItem> allItems = docs.map((doc) {
                return MaxiItem.fromMap(doc.id, doc.data() as Map<String, dynamic>);
              }).toList();

              List<MaxiItem> filteredItems = allItems.where((item) {
                if (_selectedAccessFilter != null && item.accessType != _selectedAccessFilter) {
                  return false;
                }
                if (_selectedNeckFilter != null && item.neckType != _selectedNeckFilter) {
                  return false;
                }
                if (_selectedStyleFilter != null && item.designStyle != _selectedStyleFilter) {
                  return false;
                }
                if (_searchKeyword.isEmpty) return true;
                return 'a${item.codeNumber}'.toLowerCase().contains(_searchKeyword) ||
                       item.title.toLowerCase().contains(_searchKeyword) ||
                       item.neckType.toLowerCase().contains(_searchKeyword) ||
                       item.designStyle.toLowerCase().contains(_searchKeyword);
              }).toList();

              if (filteredItems.isEmpty) {
                return const Center(child: Text('هیچ دیزاینێک بەو مەرجە نەدۆزراوەتەوە!'));
              }

              return GridView.builder(
                itemCount: filteredItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                itemBuilder: (context, index) {
                  final maxi = filteredItems[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MaxiDetailScreen(
                            maxiItem: maxi,
                            isAdmin: _isAdmin,
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
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                  child: Image.memory(maxi.imageBytes, fit: BoxFit.cover, width: double.infinity),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: maxi.accessType == 'تایبەت' ? Colors.orange : Colors.green,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      maxi.accessType,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'A${maxi.codeNumber}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink, fontSize: 13),
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
                                    Text('${maxi.price} د.ع', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 11)),
                                    Text(maxi.neckType, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                  ],
                                ),
                                if (_isAdmin)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(2),
                                        icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                                        onPressed: () => _editDesign(maxi),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(2),
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                        onPressed: () => _deleteDesign(maxi.id),
                                      ),
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
              );
            },
          ),
        ),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showAddDialog,
              backgroundColor: Colors.pink,
              icon: const Icon(Icons.add),
              label: const Text('زیادکردنی دیزاین بۆ سێرڤەر'),
            )
          : null,
    );
  }
}

class _SliverFilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverFilterDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => 55.0;

  @override
  double get minExtent => 55.0;

  @override
  bool shouldRebuild(covariant _SliverFilterDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class MaxiDetailScreen extends StatefulWidget {
  const MaxiDetailScreen({super.key, required this.maxiItem, required this.isAdmin});

  final MaxiItem maxiItem;
  final bool isAdmin;

  @override
  State<MaxiDetailScreen> createState() => _MaxiDetailScreenState();
}

class _MaxiDetailScreenState extends State<MaxiDetailScreen> {
  static final Set<String> _unlockedFiles = {};

  void _addExtraImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      var bytes = await image.readAsBytes();
      setState(() {
        widget.maxiItem.extraImagesBytes.add(bytes);
      });

      List<String> encodedExtras = widget.maxiItem.extraImagesBytes
          .map((img) => base64Encode(img))
          .toList();

      await FirebaseFirestore.instance
          .collection('maxi_designs')
          .doc(widget.maxiItem.id)
          .update({'extraImagesBytes': encodedExtras});
    }
  }

  void _showFullscreenImage(Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.memory(imageBytes),
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

  void _downloadDstFile(String fileName) {
    if (kIsWeb) {
      final blob = html.Blob([utf8.encode('Embroidery DST Content for A${widget.maxiItem.codeNumber}')]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('فایلی $fileName بە سەرکەوتوویی دابەزی!')),
    );
  }

  void _openTelegramLink() async {
    String urlStr = widget.maxiItem.telegramLink;
    if (urlStr.isEmpty) {
      urlStr = 'https://t.me/your_telegram_username';
    }
    if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
      urlStr = 'https://$urlStr';
    }
    final uri = Uri.parse(urlStr);
    if (kIsWeb) {
      html.window.open(uri.toString(), '_blank');
    }
  }

  void _showUnlockDialog(String fileName) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('داخڵکردنی کۆدی قوفڵ 🔑'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ئەم دیزاینە تایبەتە (${widget.maxiItem.dstPrice} دینار). بۆ داگرتنی فایلەکە، تکایە سەرەتا لە تێلیگرام پارە بنێرە و کۆدی قوفڵ وەرگرە:'),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: _openTelegramLink,
              icon: const Icon(Icons.send),
              label: const Text('پەیوەندیکردن لە تێلیگرام'),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'کۆدی قوفڵی ئاڵۆز لێرە بنووسە',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('پاشگەزبوونەوە')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              if (codeController.text.trim() == widget.maxiItem.unlockCode.trim()) {
                setState(() {
                  _unlockedFiles.add(widget.maxiItem.id);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('کۆدەکە ڕاستە! قوفڵەکە کرایەوە ✅')),
                );
                _downloadDstFile(fileName);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('کۆدی قوفڵ هەڵەیە! تکایە دڵنیابەرەوە ❌', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('پشکنین و داگرتن'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isFree = widget.maxiItem.accessType == 'فری';
    bool isUnlocked = isFree || widget.isAdmin || _unlockedFiles.contains(widget.maxiItem.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('کۆدی دیزاین: A${widget.maxiItem.codeNumber}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: () => _showFullscreenImage(widget.maxiItem.imageBytes),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.memory(
                    widget.maxiItem.imageBytes,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.maxiItem.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(widget.maxiItem.accessType),
                  backgroundColor: isFree ? Colors.green[100] : Colors.orange[100],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('نرخی سەرەکی: ${widget.maxiItem.price} د.ع', style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold)),
                Text('نرخی سەرقۆڵ: ${widget.maxiItem.sleevePrice} د.ع', style: const TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('جۆری مل: ${widget.maxiItem.neckType}', style: const TextStyle(fontSize: 13, color: Colors.pink, fontWeight: FontWeight.bold)),
                Text('جۆری دیزاین: ${widget.maxiItem.designStyle}', style: const TextStyle(fontSize: 13, color: Colors.purple, fontWeight: FontWeight.bold)),
              ],
            ),
            if (widget.maxiItem.telegramLink.isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: _openTelegramLink,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.send, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'پەیوەندیکردن لە تێلیگرام بۆ کڕین یان پرسیار',
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Divider(height: 30),
            const Text(
              'فایلی دیزاینی DST:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...widget.maxiItem.dstFileNames.map((fileName) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUnlocked ? Colors.blue[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isUnlocked ? Colors.blue.shade200 : Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(isUnlocked ? Icons.insert_drive_file : Icons.lock, color: isUnlocked ? Colors.blue : Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            fileName,
                            style: TextStyle(fontWeight: FontWeight.bold, color: isUnlocked ? Colors.blue : Colors.orange[800]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isFree && widget.maxiItem.dstPrice.isNotEmpty && widget.maxiItem.dstPrice != '0') ...[
                          const SizedBox(width: 8),
                          Text(
                            '(${widget.maxiItem.dstPrice} د.ع)',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUnlocked ? Colors.blue : Colors.orange,
                    ),
                    onPressed: () {
                      if (isUnlocked) {
                        _downloadDstFile(fileName);
                      } else {
                        _showUnlockDialog(fileName);
                      }
                    },
                    icon: Icon(isUnlocked ? Icons.download : Icons.lock, size: 16),
                    label: Text(isUnlocked ? 'داگرتن' : 'کردنەوەی قوفڵ (کۆد)'),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'وێنەی زیاتر:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (widget.isAdmin)
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
              child: widget.maxiItem.extraImagesBytes.isEmpty
                  ? const Center(
                      child: Text('هیچ وێنەیەکی زیاتر نییە.'),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.maxiItem.extraImagesBytes.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => _showFullscreenImage(widget.maxiItem.extraImagesBytes[index]),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                widget.maxiItem.extraImagesBytes[index],
                                width: 110,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
