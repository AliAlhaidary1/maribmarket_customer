import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_controller.dart';
import '../../core/json_util.dart';
import '../../core/promo_price.dart';
import '../../widgets/ui_helpers.dart';

// ========== Seller ==========
class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});
  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}
class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  List<Map<String,dynamic>> items=[];
  bool loading=true;
  @override
  void initState(){ super.initState(); _load();}
  Future<void> _load() async {
    final res = await appController.api.sellerOrders({'limit':20,'offset':0});
    if(!mounted) return;
    setState((){ items=res.dataMaps; loading=false; });
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات البائع')),
      body: loading? const Center(child: CircularProgressIndicator()) : items.isEmpty? EmptyState(message: appController.t('no_orders')) : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_,__)=>const SizedBox(height:8),
        itemBuilder: (_,i){
          final o=items[i];
          return Card(child: ListTile(
            title: Text('طلب #${o['id']}'),
            subtitle: Text(J.str(o['status'] ?? o['order_status'])),
            trailing: Text(money(o['total'] ?? o['final_total'], appController.currency, appController.decimals)),
            onTap: ()=> context.push('/seller/orders/${o['id']}'),
          ));
        },
      ),
    );
  }
}

class SellerOrderDetailsScreen extends StatefulWidget {
  const SellerOrderDetailsScreen({super.key, required this.id});
  final String id;
  @override
  State<SellerOrderDetailsScreen> createState()=> _SellerOrderDetailsScreenState();
}
class _SellerOrderDetailsScreenState extends State<SellerOrderDetailsScreen>{
  Map<String,dynamic>? order;
  bool loading=true;
  @override
  void initState(){ super.initState(); appController.api.sellerOrderDetails(widget.id).then((r){ if(mounted) setState((){ order=r.dataMap.isNotEmpty? r.dataMap : J.map(r.raw['data']); loading=false; }); });}
  @override
  Widget build(BuildContext context){
    if(loading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text('طلب #${widget.id}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(title: const Text('الحالة'), subtitle: Text(J.str(order?['status']))),
        ...J.maps(order?['items']).map((it)=> ListTile(title: Text(J.str(it['name'] ?? it['product_name'])), trailing: Text('x${it['quantity'] ?? it['qty']}'))),
        ListTile(title: const Text('الإجمالي'), subtitle: Text(money(order?['total'], appController.currency, appController.decimals))),
      ]),
    );
  }
}

class SellerSettlementScreen extends StatefulWidget {
  const SellerSettlementScreen({super.key});
  @override
  State<SellerSettlementScreen> createState()=> _SellerSettlementScreenState();
}
class _SellerSettlementScreenState extends State<SellerSettlementScreen>{
  List<Map<String,dynamic>> items=[];
  bool loading=true;
  @override
  void initState(){ super.initState(); appController.api.sellerSettlement().then((r){ if(mounted) setState((){ items=r.dataMaps; loading=false;}); });}
  @override
  Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('تسوية البائع')), body: loading? const Center(child: CircularProgressIndicator()) : ListView(children: items.map((e)=> ListTile(title: Text(J.str(e['title'] ?? e['id'])), subtitle: Text(money(e['amount'], appController.currency, appController.decimals)))).toList()));
  }
}

// ========== Courier ==========
class CourierDashboardScreen extends StatefulWidget {
  const CourierDashboardScreen({super.key});
  @override
  State<CourierDashboardScreen> createState()=> _CourierDashboardScreenState();
}
class _CourierDashboardScreenState extends State<CourierDashboardScreen>{
  List<Map<String,dynamic>> orders=[];
  bool loading=true;
  @override
  void initState(){ super.initState(); _load();}
  Future<void> _load() async {
    final res = await appController.api.courierOrders();
    if(!mounted) return;
    setState((){ orders=res.dataMaps; loading=false;});
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text('المندوب'), actions: [IconButton(icon: const Icon(Icons.assignment), onPressed: ()=> context.push('/courier/assignments')), IconButton(icon: const Icon(Icons.account_balance_wallet), onPressed: ()=> context.push('/courier/settlement'))]),
      body: loading? const Center(child: CircularProgressIndicator()) : orders.isEmpty? const EmptyState(message: 'لا توجد طلبات') : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        separatorBuilder: (_,__)=>const SizedBox(height:8),
        itemBuilder: (_,i){
          final o=orders[i];
          return Card(child: ListTile(title: Text('طلب #${o['id']}'), subtitle: Text(J.str(o['status'])), onTap: ()=> context.push('/courier/assignments/${o['id']}')));
        },
      ),
    );
  }
}

class CourierAssignmentsScreen extends StatefulWidget {
  const CourierAssignmentsScreen({super.key});
  @override
  State<CourierAssignmentsScreen> createState()=> _CourierAssignmentsScreenState();
}
class _CourierAssignmentsScreenState extends State<CourierAssignmentsScreen>{
  List<Map<String,dynamic>> items=[];
  bool loading=true;
  @override
  void initState(){ super.initState(); appController.api.courierAssignments().then((r){ if(mounted) setState((){ items=r.dataMaps; loading=false;}); });}
  @override
  Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('المهام')), body: loading? const Center(child: CircularProgressIndicator()) : ListView(children: items.map((e)=> ListTile(title: Text('مهمة #${e['id']}'), subtitle: Text(J.str(e['status'])), onTap: ()=> context.push('/courier/assignments/${e['id'] ?? e['order_id']}'))).toList()));
  }
}

class CourierAssignmentDetailsScreen extends StatefulWidget {
  const CourierAssignmentDetailsScreen({super.key, required this.id});
  final String id;
  @override
  State<CourierAssignmentDetailsScreen> createState()=> _CourierAssignmentDetailsScreenState();
}
class _CourierAssignmentDetailsScreenState extends State<CourierAssignmentDetailsScreen>{
  Map<String,dynamic>? data;
  bool loading=true;
  @override
  void initState(){ super.initState(); appController.api.courierAssignmentDetails(widget.id).then((r){ if(mounted) setState((){ data=r.dataMap.isNotEmpty? r.dataMap : J.map(r.raw['data']); loading=false;}); });}
  Future<void> _action(String action) async {
    final res = switch(action){
      'collect' => await appController.api.courierCollectFromSeller(widget.id, {}),
      'missing' => await appController.api.courierRecordMissingProduct(widget.id, {}),
      'deliver' => await appController.api.courierDeliverToCustomer(widget.id, {}),
      'cash' => await appController.api.courierCollectCash(widget.id, {}),
      _ => null,
    };
    if(!mounted || res==null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.ok ? 'تم' : res.message)));
  }
  @override
  Widget build(BuildContext context){
    if(loading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text('مهمة #${widget.id}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(title: const Text('الحالة'), subtitle: Text(J.str(data?['status']))),
        ListTile(title: const Text('العنوان'), subtitle: Text(J.str(data?['address']))),
        const SizedBox(height: 12),
        FilledButton(onPressed: ()=> _action('collect'), child: const Text('استلام من البائع')),
        OutlinedButton(onPressed: ()=> _action('missing'), child: const Text('تسجيل نقص')),
        FilledButton(onPressed: ()=> _action('deliver'), child: const Text('تسليم للعميل')),
        OutlinedButton(onPressed: ()=> _action('cash'), child: const Text('تحصيل نقدي')),
      ]),
    );
  }
}

class CourierSettlementScreen extends StatefulWidget {
  const CourierSettlementScreen({super.key});
  @override
  State<CourierSettlementScreen> createState()=> _CourierSettlementScreenState();
}
class _CourierSettlementScreenState extends State<CourierSettlementScreen>{
  Map<String,dynamic>? data;
  bool loading=true;
  @override
  void initState(){ super.initState(); appController.api.courierSettlement().then((r){ if(mounted) setState((){ data=r.dataMap; loading=false;}); });}
  @override
  Widget build(BuildContext context){
    if(loading) return Scaffold(appBar: AppBar(title: const Text('تسوية المندوب')), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(appBar: AppBar(title: const Text('تسوية المندوب')), body: ListView(padding: const EdgeInsets.all(16), children: [
      ListTile(title: const Text('المستحق'), subtitle: Text(money(data?['total'] ?? data?['amount'], appController.currency, appController.decimals))),
      FilledButton(onPressed: () async {
        final res = await appController.api.submitCourierSettlementBatch({});
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.ok ? 'تم الإرسال' : res.message)));
      }, child: const Text('إرسال التسوية')),
    ]));
  }
}

// ========== Admin ==========
class AdminCheckoutGroupsScreen extends StatefulWidget {
  const AdminCheckoutGroupsScreen({super.key});
  @override
  State<AdminCheckoutGroupsScreen> createState()=> _AdminCheckoutGroupsScreenState();
}
class _AdminCheckoutGroupsScreenState extends State<AdminCheckoutGroupsScreen>{
  List<Map<String,dynamic>> items=[];
  bool loading=true;
  @override
  void initState(){ super.initState(); appController.api.adminCheckoutGroups().then((r){ if(mounted) setState((){ items=r.dataMaps; loading=false;}); });}
  @override
  Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('إدارة الطلبات')), body: loading? const Center(child: CircularProgressIndicator()) : ListView(children: items.map((e)=> ListTile(title: Text('#${e['id']}'), subtitle: Text(J.str(e['status'])), onTap: ()=> context.push('/admin/checkout-groups/${e['id']}'))).toList()));
  }
}

class AdminCheckoutGroupDetailsScreen extends StatefulWidget {
  const AdminCheckoutGroupDetailsScreen({super.key, required this.id});
  final String id;
  @override
  State<AdminCheckoutGroupDetailsScreen> createState()=> _AdminCheckoutGroupDetailsScreenState();
}
class _AdminCheckoutGroupDetailsScreenState extends State<AdminCheckoutGroupDetailsScreen>{
  Map<String,dynamic>? data;
  bool loading=true;
  @override
  void initState(){ super.initState(); appController.api.adminCheckoutGroup(widget.id).then((r){ if(mounted) setState((){ data=r.dataMap.isNotEmpty? r.dataMap : J.map(r.raw['data']); loading=false;}); });}
  @override
  Widget build(BuildContext context){
    if(loading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(appBar: AppBar(title: Text('طلب إداري #${widget.id}')), body: ListView(padding: const EdgeInsets.all(16), children: [
      ListTile(title: const Text('الحالة'), subtitle: Text(J.str(data?['status']))),
      FilledButton(onPressed: () async { final res=await appController.api.cancelCheckoutGroup(widget.id); if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));}, child: const Text('إلغاء')),
    ]));
  }
}

class AdminDispatchScreen extends StatefulWidget {
  const AdminDispatchScreen({super.key});
  @override
  State<AdminDispatchScreen> createState()=> _AdminDispatchScreenState();
}
class _AdminDispatchScreenState extends State<AdminDispatchScreen>{
  List<Map<String,dynamic>> orders=[];
  List<Map<String,dynamic>> couriers=[];
  bool loading=true;
  @override
  void initState(){ super.initState(); _load();}
  Future<void> _load() async {
    final o = await appController.api.adminDispatch();
    final c = await appController.api.adminCouriers();
    if(!mounted) return;
    setState((){ orders=o.dataMaps; couriers=c.dataMaps; loading=false;});
  }
  Future<void> _assign(dynamic orderId, dynamic courierId) async {
    final res = await appController.api.assignCourierToOrder(orderId: orderId, courierId: courierId);
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.ok ? 'تم التعيين' : res.message)));
  }
  @override
  Widget build(BuildContext context){
    if(loading) return Scaffold(appBar: AppBar(title: const Text('التوزيع')), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(appBar: AppBar(title: const Text('التوزيع')), body: ListView(children: orders.map((o)=> Card(child: ListTile(
      title: Text('طلب #${o['id']}'),
      subtitle: DropdownButtonFormField<String>(items: couriers.map((c)=> DropdownMenuItem(value: '${c['id']}', child: Text(J.str(c['name'])))).toList(), onChanged: (v){ if(v!=null) _assign(o['id'], v); }, decoration: const InputDecoration(labelText: 'المندوب')),
    ))).toList()));
  }
}

class AdminReturnsScreen extends StatefulWidget {
  const AdminReturnsScreen({super.key});
  @override
  State<AdminReturnsScreen> createState()=> _AdminReturnsScreenState();
}
class _AdminReturnsScreenState extends State<AdminReturnsScreen>{
  List<Map<String,dynamic>> items=[];
  bool loading=true;
  @override
  void initState(){ super.initState(); appController.api.adminReturns().then((r){ if(mounted) setState((){ items=r.dataMaps; loading=false;}); });}
  @override
  Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('المرتجعات')), body: loading? const Center(child: CircularProgressIndicator()) : ListView(children: items.map((e)=> ListTile(title: Text('#${e['id']}'), subtitle: Text(J.str(e['reason'] ?? e['status'])))).toList()));
  }
}
