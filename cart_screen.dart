import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  // ── Quantity update / delete ──────────────
  Future<void> _updateQuantity(String productId, int newQuantity) async {
    final ref = FirebaseFirestore.instance
        .collection('carts')
        .doc(userId)
        .collection('items')
        .doc(productId);

    if (newQuantity <= 0) {
      await ref.delete();
    } else {
      await ref.update({'quantity': newQuantity});
    }
  }

  // ── Clear entire cart ─────────────────────
  Future<void> _clearCart() async {
    final items = await FirebaseFirestore.instance
        .collection('carts')
        .doc(userId)
        .collection('items')
        .get();
    for (var doc in items.docs) {
      await doc.reference.delete();
    }
  }

  // ── Place COD order → save to Firestore ──
  Future<void> _placeOrder({
    required List<QueryDocumentSnapshot> cartItems,
    required double total,
    required String name,
    required String phone,
    required String address,
  }) async {
    final orderItems = cartItems.map((item) {
      final d = item.data() as Map<String, dynamic>;
      return {
        'productId': d['productId'],
        'productName': d['productName'],
        'price': d['price'],
        'quantity': d['quantity'],
        'imageUrl': d['imageUrl'],
      };
    }).toList();

    await FirebaseFirestore.instance.collection('orders').add({
      'userId': userId,
      'customerName': name,
      'phone': phone,
      'address': address,
      'items': orderItems,
      'total': total,
      'paymentMethod': 'Cash on Delivery',
      'status': 'Pending',
      'placedAt': FieldValue.serverTimestamp(),
    });

    await _clearCart();
  }

  // ── COD Checkout Bottom Sheet ─────────────
  void _showCheckoutSheet(
      List<QueryDocumentSnapshot> cartItems, double total) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text('Delivery Details',
                        style: GoogleFonts.poppins(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Cash will be collected on delivery',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey.shade500)),
                    const SizedBox(height: 20),

                    // COD badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(children: [
                        Icon(Icons.money, color: Colors.green.shade700),
                        const SizedBox(width: 10),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cash on Delivery',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade800)),
                              Text('Pay when your order arrives',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.green.shade600)),
                            ]),
                        const Spacer(),
                        Text('\$${total.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Colors.green.shade800)),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    // Full Name
                    Text('Full Name',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Ariba Khizar',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    Text('Phone Number',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'e.g. 03001234567',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().length < 10)
                          ? 'Enter a valid phone number'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Address
                    Text('Delivery Address',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: addressCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'House #, Street, City',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter delivery address'
                          : null,
                    ),
                    const SizedBox(height: 28),

                    // Place Order button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheetState(() => isLoading = true);
                                try {
                                  await _placeOrder(
                                    cartItems: cartItems,
                                    total: total,
                                    name: nameCtrl.text.trim(),
                                    phone: phoneCtrl.text.trim(),
                                    address: addressCtrl.text.trim(),
                                  );
                                  if (!mounted) return;
                                  Navigator.pop(ctx); // close sheet
                                  _showSuccessDialog();
                                } catch (e) {
                                  setSheetState(() => isLoading = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)
                            : Text('🛵  Place Order — \$${total.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  // ── Success Dialog ────────────────────────
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.green.shade50, shape: BoxShape.circle),
              child: Icon(Icons.check_circle,
                  color: Colors.green.shade600, size: 60),
            ),
            const SizedBox(height: 16),
            Text('Order Placed! 🎉',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Your order has been placed successfully.\nOur team will contact you soon.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.money, color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 6),
                  Text('Pay on Delivery',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // go back to products
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Continue Shopping',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Cart',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Clear Cart'),
                  content:
                      const Text('Remove all items from your cart?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) await _clearCart();
            },
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            label: Text('Clear',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('carts')
            .doc(userId)
            .collection('items')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: Colors.deepPurple));
          }

          final cartItems = snapshot.data?.docs ?? [];

          // Empty cart
          if (cartItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Your cart is empty',
                      style: GoogleFonts.poppins(
                          fontSize: 18, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text('Add some products to get started!',
                      style: GoogleFonts.poppins(
                          color: Colors.grey.shade400)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text('Browse Products',
                        style: GoogleFonts.poppins()),
                  ),
                ],
              ),
            );
          }

          // Calculate total
          double total = 0;
          for (var item in cartItems) {
            final d = item.data() as Map<String, dynamic>;
            total += (d['price'] ?? 0) * (d['quantity'] ?? 1);
          }

          return Column(
            children: [
              // ── Cart items list ─────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 8),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    final data = item.data() as Map<String, dynamic>;
                    final qty = data['quantity'] ?? 1;
                    final price =
                        (data['price'] ?? 0).toDouble();
                    final itemTotal = price * qty;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 4),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(children: [
                          // Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              data['imageUrl'] ?? '',
                              width: 65,
                              height: 65,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 65,
                                height: 65,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image,
                                    color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Name + price
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['productName'] ?? 'Product',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '\$${price.toStringAsFixed(2)} each',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                                Text(
                                  'Total: \$${itemTotal.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.deepPurple),
                                ),
                              ],
                            ),
                          ),

                          // Quantity controls
                          Column(children: [
                            Row(children: [
                              InkWell(
                                onTap: () =>
                                    _updateQuantity(item.id, qty - 1),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.red.shade200),
                                  ),
                                  child: Icon(Icons.remove,
                                      size: 16,
                                      color: Colors.red.shade700),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                child: Text('$qty',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                              ),
                              InkWell(
                                onTap: () =>
                                    _updateQuantity(item.id, qty + 1),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.green.shade200),
                                  ),
                                  child: Icon(Icons.add,
                                      size: 16,
                                      color: Colors.green.shade700),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () =>
                                  _updateQuantity(item.id, 0),
                              child: Text('Remove',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.red.shade400)),
                            ),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
              ),

              // ── Bottom total + checkout ─────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 10,
                        offset: const Offset(0, -2))
                  ],
                ),
                child: Column(children: [
                  // Items count + total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${cartItems.length} item${cartItems.length > 1 ? 's' : ''}',
                        style: GoogleFonts.poppins(
                            color: Colors.grey.shade500, fontSize: 13),
                      ),
                      Text(
                        'Total: \$${total.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.deepPurple),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // COD label
                  Row(children: [
                    Icon(Icons.money,
                        size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 4),
                    Text('Cash on Delivery available',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.green.shade600)),
                  ]),
                  const SizedBox(height: 12),

                  // Checkout button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showCheckoutSheet(cartItems, total),
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: Text(
                        'Proceed to Checkout',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}