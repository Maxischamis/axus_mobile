import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product.dart';

class ProductCard extends StatefulWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final AnimationController _badgeController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _badgeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  Color _parseColor(String hexColor) {
    var color = hexColor.replaceAll('#', '');
    if (color.length == 6) color = 'FF$color';
    return Color(int.parse(color, radix: 16));
  }

  double? _calculateSavings() {
    final product = widget.product;
    if (product.listPrice == null) return null;
    try {
      double current =
          double.parse(product.price.replaceAll('.', '').replaceAll(',', '.'));
      double list = double.parse(
          product.listPrice!.replaceAll('.', '').replaceAll(',', '.'));
      if (list > current) return list - current;
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      // ignore: avoid_print
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final storeColor = _parseColor(product.store.color);
    final savings = _calculateSavings();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.08)),
        boxShadow: [
          BoxShadow(
            color: storeColor.withAlpha((0.08 * 255).round()),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _openLink(product.link);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildImageStack(storeColor)),
              _buildContent(storeColor, savings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageStack(Color storeColor) {
    final product = widget.product;
    return Stack(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF0F2F5)],
            ),
          ),
          child: Hero(
            tag: product.link,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CachedNetworkImage(
                imageUrl: product.img,
                placeholder: (context, url) => _ShimmerPlaceholder(
                    controller: _shimmerController, color: storeColor),
                errorWidget: (context, url, error) => Icon(
                    Icons.inventory_2_outlined,
                    size: 30,
                    color: storeColor.withAlpha((0.2 * 255).round())),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        if (product.discount > 0)
          Positioned(
            top: 12,
            left: 12,
            child: ScaleTransition(
              scale: Tween(begin: 0.95, end: 1.06).animate(CurvedAnimation(
                  parent: _badgeController, curve: Curves.easeInOut)),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.red.withAlpha((0.28 * 255).round()),
                        blurRadius: 10)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_offer_rounded,
                        color: Colors.white, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      '-${product.discount}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 15,
          right: 15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((0.8 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: storeColor.withAlpha((0.4 * 255).round())),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: storeColor),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    product.store.name.split(' ')[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(Color storeColor, double? savings) {
    final product = widget.product;
    final priceParts = product.price.contains(',')
        ? product.price.split(',')
        : [product.price, '00'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (product.listPrice != null)
            Text(
              '\$${product.listPrice}',
              style: const TextStyle(
                color: Colors.white12,
                fontSize: 11,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${priceParts[0]}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  ',${priceParts[1]}',
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.3 * 255).round()),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (product.unitPrice != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                product.unitPrice!.toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 9,
                    fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShimmerPlaceholder extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _ShimmerPlaceholder({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment(-1 - controller.value * 2, -0.3),
                end: Alignment(1 + controller.value * 2, 0.3),
                colors: [
                  Colors.white12,
                  color.withAlpha((0.12 * 255).round()),
                  Colors.white12
                ],
                stops: const [0.1, 0.5, 0.9],
              ).createShader(rect);
            },
            blendMode: BlendMode.srcATop,
            child: Container(color: const Color.fromRGBO(255, 255, 255, 0.02)),
          ),
        );
      },
    );
  }
}
