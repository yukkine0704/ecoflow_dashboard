import 'dart:math';

import 'app_gooey_toast_models.dart';

abstract interface class AppGooeyToastHostController {
  void showToast(AppToastData toast);
  void updateToast(
    String id, {
    String? title,
    AppToastType? type,
    String? description,
    bool? dismissible,
    Duration? duration,
  });
  void dismissToast(String id);
  void dismissAllToasts();
}

class AppGooeyToast {
  AppGooeyToast._();

  static final AppGooeyToast instance = AppGooeyToast._();

  AppGooeyToastHostController? _host;

  void bindHost(AppGooeyToastHostController host) => _host = host;
  void unbindHost(AppGooeyToastHostController host) {
    if (_host == host) {
      _host = null;
    }
  }

  String show(
    String title, {
    AppToastType type = AppToastType.normal,
    AppToastConfig config = const AppToastConfig(),
  }) {
    final id = _newId();
    _host?.showToast(
      AppToastData(
        id: id,
        title: title,
        type: type,
        createdAt: DateTime.now(),
        description: config.description,
        duration: config.duration,
        position: config.position,
        dismissible: config.dismissible,
        pauseOnInteraction: config.pauseOnInteraction,
        showTimestamp: config.showTimestamp,
        meta: config.meta,
        action: config.action,
        bodyLayout: config.bodyLayout,
      ),
    );
    return id;
  }

  String success(
    String title, {
    AppToastConfig config = const AppToastConfig(),
  }) {
    return show(title, type: AppToastType.success, config: config);
  }

  String error(String title, {AppToastConfig config = const AppToastConfig()}) {
    return show(title, type: AppToastType.error, config: config);
  }

  String warning(
    String title, {
    AppToastConfig config = const AppToastConfig(),
  }) {
    return show(title, type: AppToastType.warning, config: config);
  }

  String info(String title, {AppToastConfig config = const AppToastConfig()}) {
    return show(title, type: AppToastType.info, config: config);
  }

  void dismiss(String id) => _host?.dismissToast(id);
  void dismissAll() => _host?.dismissAllToasts();

  Future<T> promise<T>(
    Future<T> future, {
    required String loading,
    required String success,
    required String error,
    AppToastConfig config = const AppToastConfig(),
    String Function(T value)? successDescription,
    String Function(Object err)? errorDescription,
  }) async {
    final id = show(
      loading,
      type: AppToastType.loading,
      config: config.copyWith(
        dismissible: false,
        duration: const Duration(days: 1),
      ),
    );

    try {
      final result = await future;
      _host?.updateToast(
        id,
        title: success,
        type: AppToastType.success,
        description: successDescription?.call(result) ?? config.description,
        dismissible: true,
        duration: config.duration,
      );
      return result;
    } catch (e) {
      _host?.updateToast(
        id,
        title: error,
        type: AppToastType.error,
        description: errorDescription?.call(e) ?? config.description,
        dismissible: true,
        duration: config.duration,
      );
      rethrow;
    }
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';
}

final appGooeyToast = AppGooeyToast.instance;

extension on AppToastConfig {
  AppToastConfig copyWith({
    String? description,
    Duration? duration,
    AppToastPosition? position,
    bool? dismissible,
    bool? pauseOnInteraction,
    bool? showTimestamp,
    String? meta,
    AppToastAction? action,
    AppToastBodyLayout? bodyLayout,
  }) {
    return AppToastConfig(
      description: description ?? this.description,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      dismissible: dismissible ?? this.dismissible,
      pauseOnInteraction: pauseOnInteraction ?? this.pauseOnInteraction,
      showTimestamp: showTimestamp ?? this.showTimestamp,
      meta: meta ?? this.meta,
      action: action ?? this.action,
      bodyLayout: bodyLayout ?? this.bodyLayout,
    );
  }
}
