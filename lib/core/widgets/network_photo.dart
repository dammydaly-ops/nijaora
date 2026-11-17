import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';

class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.image_outlined,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final image = (url == null || url!.isEmpty)
        ? _fallback(context)
        : _buildImage(context);

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  Widget _buildImage(BuildContext context) {
    final bytes = _decodeDataUrl(url!);
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) => _fallback(context),
      );
    }

    return CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, _) => Container(
        width: width,
        height: height,
        color: context.palette.surfaceAlt,
      ),
      errorWidget: (context, _, _) => _fallback(context),
    );
  }

  Uint8List? _decodeDataUrl(String value) {
    if (!value.startsWith('data:image/')) return null;
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(value.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: context.palette.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: context.palette.muted, size: 22),
    );
  }
}
