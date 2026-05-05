import 'package:flutter/material.dart';

enum AppToastType { normal, success, error, warning, info, loading }

enum AppToastPosition { topCenter, bottomCenter }

enum AppToastBodyLayout { left, center, right, spread }

class AppToastAction {
  const AppToastAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class AppToastConfig {
  const AppToastConfig({
    this.description,
    this.duration = const Duration(milliseconds: 5000),
    this.position = AppToastPosition.topCenter,
    this.dismissible = true,
    this.pauseOnInteraction = true,
    this.showTimestamp = false,
    this.meta,
    this.action,
    this.bodyLayout = AppToastBodyLayout.left,
  });

  final String? description;
  final Duration duration;
  final AppToastPosition position;
  final bool dismissible;
  final bool pauseOnInteraction;
  final bool showTimestamp;
  final String? meta;
  final AppToastAction? action;
  final AppToastBodyLayout bodyLayout;
}

class AppToastData {
  const AppToastData({
    required this.id,
    required this.title,
    required this.type,
    required this.createdAt,
    required this.description,
    required this.duration,
    required this.position,
    required this.dismissible,
    required this.pauseOnInteraction,
    required this.showTimestamp,
    required this.meta,
    required this.action,
    required this.bodyLayout,
  });

  final String id;
  final String title;
  final AppToastType type;
  final DateTime createdAt;
  final String? description;
  final Duration duration;
  final AppToastPosition position;
  final bool dismissible;
  final bool pauseOnInteraction;
  final bool showTimestamp;
  final String? meta;
  final AppToastAction? action;
  final AppToastBodyLayout bodyLayout;

  AppToastData copyWith({
    String? title,
    AppToastType? type,
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
    return AppToastData(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      createdAt: createdAt,
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
