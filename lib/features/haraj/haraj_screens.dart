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

  Future<void> _deletePost(dynamic id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('حذف الإعلان؟'), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx,false), child: const Text('إلغاء')), FilledButton(onPressed: ()=>Navigator.pop(ctx,true), child: const Text('حذف'))]));
    if (ok != true) return;
    final res = await appController.api.harajDelete(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.ok ? 'تم الحذف' : res.message)));
    if (res.ok) _load();
  }

  Future<void> _markSold(dynamic id) async {
    final res = await appController.api.harajMarkSold(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.ok ? 'تم التحديث' : res.message)));
    if (res.ok) _load();
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
                : LayoutBuilder(builder: (ctx, c){
                    final count = c.maxWidth >= 900 ? 4 : c.maxWidth >= 600 ? 3 : 2;
                    return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: count,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: count > 2 ? 0.72 : 0.72,
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
                            if (widget.mine) Row(
                              children: [
                                IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: ()=> context.push('/haraj/edit/${post['id']}')),
                                IconButton(icon: const Icon(Icons.delete, size: 16), onPressed: ()=> _deletePost(post['id'])),
                                IconButton(icon: const Icon(Icons.check, size: 16), onPressed: ()=> _markSold(post['id'])),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );}),
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
  dynamic replyTo;
  double userRating = 0;
  bool blocked = false;

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
      post = result.dataMap.isNotEmpty ? result.dataMap : J.map(result.raw['data']);
      comments = c.dataMaps;
      loading = false;
      failed = !result.ok || post == null || post!.isEmpty;
    });
    // load ratings if post has user
    final userId = post?['user_id'] ?? post?['user']?['id'];
    if (userId != null) {
      final r = await appController.api.harajUserRatings(userId);
      if (mounted && r.ok) {
        // could show
      }
    }
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

  Future<void> _addComment() async {
    if (comment.text.trim().isEmpty) return;
    final res = await appController.api.harajAddComment(widget.id, comment.text.trim(), parentId: replyTo);
    if (!mounted) return;
    if (res.ok) {
      comment.clear();
      replyTo = null;
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  Future<void> _updateComment(dynamic id, String old) async {
    final ctrl = TextEditingController(text: old);
    final ok = await showDialog<bool>(context: context, builder: (ctx)=> AlertDialog(title: const Text('تعديل التعليق'), content: TextField(controller: ctrl), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx,false), child: const Text('إلغاء')), FilledButton(onPressed: ()=>Navigator.pop(ctx,true), child: const Text('حفظ'))]));
    if (ok != true) return;
    final res = await appController.api.harajUpdateComment(id, ctrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.ok ? 'تم التعديل' : res.message)));
    if (res.ok) _load();
  }

  Future<void> _deleteComment(dynamic id) async {
    final res = await appController.api.harajDeleteComment(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.ok ? 'تم الحذف' : res.message)));
    if (res.ok) _load();
  }

  Future<void> _rateUser() async {
    final uid = post?['user_id'] ?? post?['user']?['id'];
    if (uid == null) return;
    double rating = 5;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx)=> StatefulBuilder(builder: (ctx, setS)=> AlertDialog(title: const Text('تقييم البائع'), content: Column(mainAxisSize: MainAxisSize.min, children: [Slider(value: rating, min: 1, max: 5, divisions: 4, label: '$rating', onChanged: (v)=> setS(()=> rating=v)), TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'تعليق'))]), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx,false), child: const Text('إلغاء')), FilledButton(onPressed: ()=>Navigator.pop(ctx,true), child: const Text('تقييم'))])));
    if (ok != true) return;
    final res = await appController.api.harajRate({'user_id': uid, 'rate': rating, 'review': ctrl.text});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.ok ? 'تم التقييم' : res.message)));
  }

  Future<void> _toggleBlock() async {
    final uid = post?['user_id'] ?? post?['user']?['id'];
    if (uid == null) return;
    final res = blocked ? await appController.api.harajUnblock(uid) : await appController.api.harajBlock(uid);
    if (!mounted) return;
    if (res.ok) setState(()=> blocked = !blocked);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.ok ? (blocked ? 'تم الحظر' : 'تم إلغاء الحظر') : res.message)));
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    final isMine = '${post?['user_id']}' == '${app.user?['id']}' && app.isLoggedIn;
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
      appBar: AppBar(title: Text(J.str(post!['title'])), actions: [
        if (isMine) IconButton(icon: const Icon(Icons.edit), onPressed: ()=> context.push('/haraj/edit/${post!['id']}')),
        if (isMine) IconButton(icon: const Icon(Icons.delete), onPressed: () async { final r=await appController.api.harajDelete(post!['id']); if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message))); if(r.ok) context.pop(); }}),
        IconButton(icon: Icon(blocked ? Icons.block : Icons.person_off), onPressed: _toggleBlock),
        IconButton(icon: const Icon(Icons.star), onPressed: _rateUser),
      ]),
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
          Text('التعليقات', style: const TextStyle(fontWeight: FontWeight.bold)),
          ...comments.map(
            (item) => ListTile(
              title: Text(J.str(item['comment'] ?? item['body'])),
              subtitle: Text(J.str(item['user_name'] ?? item['user']?['name'] ?? '')),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.reply, size: 16), onPressed: ()=> setState(()=> replyTo = item['id'])),
                if ('${item['user_id']}' == '${app.user?['id']}') IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: ()=> _updateComment(item['id'], J.str(item['comment'] ?? item['body']))),
                if ('${item['user_id']}' == '${app.user?['id']}') IconButton(icon: const Icon(Icons.delete, size: 16), onPressed: ()=> _deleteComment(item['id'])),
              ]),
            ),
          ),
          if (replyTo != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('رد على #$replyTo', style: const TextStyle(fontSize: 12, color: Colors.grey))),
          if (app.isLoggedIn)
            TextField(
              controller: comment,
              decoration: InputDecoration(
                hintText: app.t('write_comment'),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
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
  List<XFile> images = [];
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
      final data = FormData();
      data.fields.addAll([
        MapEntry('title', title.text.trim()),
        MapEntry('price', price.text.trim()),
        MapEntry('description', description.text.trim()),
        MapEntry('category_id', '$categoryId'),
        MapEntry('city_id', '${app.city?['id'] ?? ''}'),
        MapEntry('contact_whatsapp', whatsapp.text.trim()),
      ]);
      for (final img in images) {
        data.files.add(MapEntry('images[]', await MultipartFile.fromFile(img.path, filename: img.name)));
      }
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
              final picked = await ImagePicker().pickMultiImage();
              if (picked.isNotEmpty && mounted) setState(() => images = picked);
            },
            icon: const Icon(Icons.image),
            label: Text(images.isEmpty ? app.t('haraj_photo') : '${images.length} صور'),
          ),
          if (images.isNotEmpty) Wrap(children: images.map((e)=> Padding(padding: const EdgeInsets.all(4), child: Text(e.name, style: const TextStyle(fontSize: 11)))).toList()),
          FilledButton(
            onPressed: busy ? null : _submit,
            child: busy ? const BusySpinner() : Text(app.t('confirm')),
          ),
        ],
      ),
    );
  }
}

class HarajEditScreen extends StatefulWidget {
  const HarajEditScreen({super.key, required this.id});
  final String id;
  @override
  State<HarajEditScreen> createState() => _HarajEditScreenState();
}

class _HarajEditScreenState extends State<HarajEditScreen> {
  final title = TextEditingController();
  final price = TextEditingController();
  final description = TextEditingController();
  final whatsapp = TextEditingController();
  List<Map<String, dynamic>> categories = [];
  String? categoryId;
  List<XFile> newImages = [];
  List<Map<String, dynamic>> existingImages = [];
  bool loading = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final catRes = await appController.api.harajCategoriesAll();
    final postRes = await appController.api.harajPost(widget.id);
    if (!mounted) return;
    setState(() {
      categories = catRes.dataMaps;
      final post = postRes.dataMap;
      title.text = J.str(post['title']);
      price.text = J.str(post['price']);
      description.text = J.str(post['description']);
      whatsapp.text = J.str(post['contact_whatsapp']);
      categoryId = '${post['category_id'] ?? ''}';
      existingImages = J.maps(post['images']);
      loading = false;
    });
  }

  Future<void> _submit() async {
    setState(()=> busy=true);
    final data = FormData();
    data.fields.addAll([
      MapEntry('title', title.text.trim()),
      MapEntry('price', price.text.trim()),
      MapEntry('description', description.text.trim()),
      if (categoryId != null) MapEntry('category_id', '$categoryId'),
      MapEntry('city_id', '${appController.city?['id'] ?? ''}'),
      MapEntry('contact_whatsapp', whatsapp.text.trim()),
    ]);
    for (final img in newImages) {
      data.files.add(MapEntry('images[]', await MultipartFile.fromFile(img.path, filename: img.name)));
    }
    final res = await appController.api.harajUpdate(widget.id, data);
    if (!mounted) return;
    setState(()=> busy=false);
    if (res.ok) context.pop(); else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
  }

  Future<void> _deleteImage(dynamic imageId) async {
    final res = await appController.api.harajDeleteImage(widget.id, imageId);
    if (!mounted) return;
    if (res.ok) setState(()=> existingImages.removeWhere((e)=> '${e['id']}'=='$imageId'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.ok ? 'تم الحذف' : res.message)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الإعلان')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
        TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر')),
        DropdownButtonFormField<String>(initialValue: categories.any((c)=> '${c['id']}'=='$categoryId') ? '$categoryId' : null, items: categories.map((cat)=> DropdownMenuItem(value: '${cat['id']}', child: Text(J.str(cat['name'])))).toList(), onChanged: (v)=> setState(()=> categoryId=v), decoration: const InputDecoration(labelText: 'الفئة')),
        TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'الوصف')),
        TextField(controller: whatsapp, decoration: const InputDecoration(labelText: 'واتساب')),
        if (existingImages.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('الصور الحالية'),
          Wrap(children: existingImages.map((img)=> Stack(children: [Padding(padding: const EdgeInsets.all(4), child: SizedBox(width: 80, height: 80, child: AppImage(J.str(img['image_url'] ?? img['url'])))), Positioned(top: 0, right: 0, child: IconButton(icon: const Icon(Icons.close, size: 16), onPressed: ()=> _deleteImage(img['id'])))] )).toList()),
        ],
        TextButton.icon(onPressed: () async { final picked = await ImagePicker().pickMultiImage(); if(mounted) setState(()=> newImages = picked); }, icon: const Icon(Icons.image), label: Text(newImages.isEmpty ? 'إضافة صور' : '${newImages.length} صور جديدة')),
        FilledButton(onPressed: busy ? null : _submit, child: busy ? const BusySpinner() : const Text('حفظ')),
      ]),
    );
  }
}
