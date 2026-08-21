import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_controller.dart';
import '../../core/json_util.dart';
import '../../core/promo_price.dart';
import '../../widgets/app_image.dart';
import '../../widgets/ui_helpers.dart';

class HarajListScreen extends StatefulWidget {
  const HarajListScreen({super.key, this.mine = false});
  final bool mine;

  @override
  State<HarajListScreen> createState() => _HarajListScreenState();
}

class _HarajListScreenState extends State<HarajListScreen> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> categories = [];
  String? categoryId;
  final search = TextEditingController();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final params = {
      'page': 1,
      'per_page': 30,
      if (appController.city?['id'] != null)
        'city_id': appController.city!['id'],
      if (categoryId != null) 'category_id': categoryId,
      if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
    };
    final posts = widget.mine
        ? await appController.api.harajMyPosts(params)
        : await appController.api.harajPosts(params);
    final cats = await appController.api.harajCategories();
    if (!mounted) return;
    setState(() {
      items = posts.dataMaps;
      categories = cats.dataMaps;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    if (widget.mine && !app.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('إعلاناتي')),
        body: const LoginRequired(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mine ? 'إعلاناتي' : 'حراج'),
        actions: [
          if (!widget.mine)
            IconButton(
              onPressed: () => app.isLoggedIn
                  ? context.push('/haraj/create')
                  : context.push('/login'),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: app.t('search'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          if (categories.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ChoiceChip(
                    label: Text(app.t('all')),
                    selected: categoryId == null,
                    onSelected: (_) {
                      categoryId = null;
                      _load();
                    },
                  ),
                  ...categories.map(
                    (cat) => Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: ChoiceChip(
                        label: Text(J.str(cat['name'])),
                        selected: '$categoryId' == '${cat['id']}',
                        onSelected: (_) {
                          categoryId = '${cat['id']}';
                          _load();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? EmptyState(
                    icon: Icons.campaign_outlined,
                    message: app.t('no_haraj_posts'),
                    actionLabel: app.isLoggedIn ? app.t('new_haraj') : null,
                    onAction: app.isLoggedIn
                        ? () => context.push('/haraj/create')
                        : null,
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final post = items[i];
                      return InkWell(
                        onTap: () => context.push('/haraj/${post['id']}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AppImage(
                                  J.str(post['image_url'] ?? post['thumbnail']),
                                  placeholder: app.placeholder,
                                ),
                              ),
                            ),
                            Text(J.str(post['title']), maxLines: 2),
                            Text(
                              money(post['price'], app.currency, app.decimals),
                              style: TextStyle(color: app.accentColor),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class HarajDetailsScreen extends StatefulWidget {
  const HarajDetailsScreen({super.key, required this.id});
  final String id;

  @override
  State<HarajDetailsScreen> createState() => _HarajDetailsScreenState();
}

class _HarajDetailsScreenState extends State<HarajDetailsScreen> {
  Map<String, dynamic>? post;
  List<Map<String, dynamic>> comments = [];
  final comment = TextEditingController();
  bool loading = true;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await appController.api.harajPost(widget.id);
    final c = await appController.api.harajComments(widget.id);
    if (!mounted) return;
    setState(() {
      post = result.dataMap;
      comments = c.dataMaps;
      loading = false;
      failed = !result.ok || result.dataMap.isEmpty;
    });
  }

  Future<void> _openWhatsApp() async {
    final app = appController;
    final phone = J.str(post?['contact_whatsapp']).replaceAll(RegExp(r'[^\d]'), '');
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(app.t('whatsapp_not_available'))),
      );
      return;
    }
    final title = J.str(post?['title']);
    final text = app.t('whatsapp_message').replaceAll('{{title}}', title);
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(app.t('whatsapp_not_available'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (failed || post == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.error_outline,
          message: app.t('network_error'),
          actionLabel: app.t('retry'),
          onAction: () {
            setState(() {
              loading = true;
              failed = false;
            });
            _load();
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(J.str(post!['title']))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: AppImage(
              J.str(post!['image_url']),
              placeholder: app.placeholder,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            J.str(post!['title']),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            money(post!['price'], app.currency, app.decimals),
            style: TextStyle(color: app.accentColor, fontSize: 18),
          ),
          Text(J.str(post!['description'])),
          const Divider(),
          ...comments.map(
            (item) => ListTile(
              title: Text(J.str(item['comment'] ?? item['body'])),
              subtitle: Text(J.str(item['user_name'])),
            ),
          ),
          if (app.isLoggedIn)
            TextField(
              controller: comment,
              decoration: InputDecoration(
                hintText: app.t('write_comment'),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    if (comment.text.trim().isEmpty) return;
                    await app.api.harajAddComment(widget.id, comment.text);
                    comment.clear();
                    if (mounted) _load();
                  },
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _openWhatsApp,
                  icon: const Icon(Icons.chat),
                  label: Text(app.t('contact_seller')),
                ),
              ),
            ),
    );
  }
}

class HarajCreateScreen extends StatefulWidget {
  const HarajCreateScreen({super.key});

  @override
  State<HarajCreateScreen> createState() => _HarajCreateScreenState();
}

class _HarajCreateScreenState extends State<HarajCreateScreen> {
  final title = TextEditingController();
  final price = TextEditingController();
  final description = TextEditingController();
  final whatsapp = TextEditingController();
  List<Map<String, dynamic>> categories = [];
  String? categoryId;
  XFile? image;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    appController.api.harajCategoriesAll().then((res) {
      if (!mounted) return;
      setState(() => categories = res.dataMaps);
    });
  }

  @override
  void dispose() {
    title.dispose();
    price.dispose();
    description.dispose();
    whatsapp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = appController;
    if (title.text.trim().isEmpty ||
        price.text.trim().isEmpty ||
        categoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(app.t('fill_required_fields'))));
      return;
    }
    if (whatsapp.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(app.t('whatsapp_required_for_haraj'))));
      return;
    }
    setState(() => busy = true);
    try {
      final data = FormData.fromMap({
        'title': title.text.trim(),
        'price': price.text.trim(),
        'description': description.text.trim(),
        'category_id': categoryId,
        'city_id': app.city?['id'],
        'contact_whatsapp': whatsapp.text.trim(),
        if (image != null)
          'images[]': await MultipartFile.fromFile(
            image!.path,
            filename: image!.name,
          ),
      });
      final result = await app.api.harajCreate(data);
      if (!mounted) return;
      if (result.ok) {
        context.pop();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    if (!app.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(app.t('new_haraj'))),
        body: const LoginRequired(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(app.t('new_haraj'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: title,
            decoration: InputDecoration(labelText: app.t('haraj_title')),
          ),
          TextField(
            controller: price,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: app.t('price')),
          ),
          DropdownButtonFormField<String>(
            initialValue: categoryId,
            items: categories
                .map(
                  (cat) => DropdownMenuItem(
                    value: '${cat['id']}',
                    child: Text(J.str(cat['name'])),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => categoryId = v),
            decoration: InputDecoration(labelText: app.t('categories')),
          ),
          TextField(
            controller: description,
            maxLines: 4,
            decoration: InputDecoration(labelText: app.t('haraj_description')),
          ),
          TextField(
            controller: whatsapp,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: '${app.t('whatsapp_number')} *',
              helperText: app.t('whatsapp_preferred_hint'),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final picked = await ImagePicker().pickImage(
                source: ImageSource.gallery,
              );
              if (picked != null && mounted) setState(() => image = picked);
            },
            icon: const Icon(Icons.image),
            label: Text(image?.name ?? app.t('haraj_photo')),
          ),
          FilledButton(
            onPressed: busy ? null : _submit,
            child: busy ? const BusySpinner() : Text(app.t('confirm')),
          ),
        ],
      ),
    );
  }
}
