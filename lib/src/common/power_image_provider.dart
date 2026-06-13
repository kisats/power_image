import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:power_image/src/tools/power_image_monitor.dart';
import 'package:power_image_ext/image_provider_ext.dart';

import '../external/power_external_image_provider.dart';
import '../texture/power_texture_image_provider.dart';
import 'power_image_loader.dart';
import '../options/power_image_request_options.dart';
import 'dart:ui' as ui;

abstract class PowerImageProvider extends ImageProviderExt<PowerImageProvider> {
  factory PowerImageProvider.options(PowerImageRequestOptions options) {
    /// renderingType null case
    if (options.renderingType == null) {
      options = PowerImageRequestOptions(
          src: options.src,
          imageType: options.imageType,
          renderingType: PowerImageLoader.instance.globalRenderType,
          imageWidth: options.imageWidth,
          imageHeight: options.imageHeight);
    }

    /// must use one of renderingTypeExternal \ renderingTypeTexture
    assert(options.renderingType == renderingTypeExternal || options.renderingType == renderingTypeTexture);
    if (options.renderingType == renderingTypeExternal) {
      return PowerExternalImageProvider(options);
    } else {
      return PowerTextureImageProvider(options);
    }
  }

  PowerImageRequestOptions options;

  PowerImageProvider(this.options, {this.scale = 1.0});

  double scale;

  @override
  ImageStreamCompleter loadImage(PowerImageProvider key, ImageDecoderCallback? decode) {
    final chunkEvents = StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: scale,
    );
  }

  ImageStreamCompleter? _completer;

  Future<ui.Codec> _loadAsync(PowerImageProvider key, StreamController<ImageChunkEvent> chunkEvents, ImageDecoderCallback? decode) async {
    try {
      void onProgress(double progress) {
        chunkEvents.add(
          ImageChunkEvent(cumulativeBytesLoaded: (progress * 100).round(), expectedTotalBytes: 100),
        );
      }

      PowerImageCompleter powerImageCompleter = PowerImageLoader.instance.loadImage(options, onProgress: onProgress);

      Map map = await powerImageCompleter.completer!.future;
      bool? success = map['success'];

      bool? isMultiFrame = map['_multiFrame'];
      if (isMultiFrame == true) {
        _completer!.addOnLastListenerRemovedCallback(() {
          scheduleMicrotask(() {
            PaintingBinding.instance.imageCache.evict(key);
          });
        });
      }
      _completer = null;

      if (success != true) {
        final PowerImageLoadException exception = PowerImageLoadException(nativeResult: map);
        PowerImageMonitor.instance().anErrorOccurred(exception);
        throw exception;
      }

      int handle = map['handle'];
      int length = map['length'];
      int width = map['width'];
      int height = map['height'];
      int? rowBytes = map['rowBytes'];

      ui.PixelFormat pixelFormat = ui.PixelFormat.values[map['flutterPixelFormat'] ?? 0];

      Pointer<Uint8> pointer = Pointer<Uint8>.fromAddress(handle);

      Uint8List pixels = pointer.asTypedList(length);

      final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);

      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        pixelFormat: pixelFormat,
        rowBytes: rowBytes,
      );

      return descriptor.instantiateCodec();
    } catch (e) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    } finally {
      chunkEvents.close();
      PowerImageLoader.instance.releaseImageRequest(options);
    }
  }

  FutureOr<ImageInfo> createImageInfo(Map map);

  @override
  Future<PowerImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<PowerImageProvider>(this);
  }

  @override
  bool operator ==(dynamic other) {
    //TODO options判断相等
    if (other.runtimeType != runtimeType) return false;
    final PowerImageProvider typedOther = other;
    return options == typedOther.options && scale == typedOther.scale;
  }

  @override
  String toString() => '$runtimeType("$options", scale: $scale)';

  @override
  void dispose() {}
}

class PowerImageLoadException implements Exception {
  /// Creates a [PowerImageLoadException] with the specified native State [state]
  /// and request [uniqueKey].
  PowerImageLoadException({required this.nativeResult}) : _message = 'Power Image request failed. For details, see the variable nativeResult';

  /// 0 = {map entry} "success" -> false
  /// 1 = {map entry} "uniqueKey" -> "{src: http://img.alicdn.com//bao//uploaded//i2//O1CN01SNnaus2KLND4UQngH_!!0-fleamarket.jpg}_imageTyp..."
  /// 2 = {map entry} "width" -> 0
  /// 3 = {map entry} "errMsg" -> "failPhenixEvent.getResultCode()=404"
  /// 4 = {map entry} "eventName" -> "onReceiveImageEvent"
  /// 5 = {map entry} "state" -> "loadFailed"
  /// 6 = {map entry} "height" -> 0
  final Map nativeResult;

  /// A human-readable error message.
  final String _message;

  @override
  String toString() => _message;
}
