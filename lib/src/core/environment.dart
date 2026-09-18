part of 'package:graphx/graphx.dart';

abstract final class _GEnvironmentAspect {
  static const textScaler = 1 << 0;
  static const brightness = 1 << 1;
}

/// Host environment properties that changed since the previous sync.
@immutable
final class GEnvironmentChange {
  const GEnvironmentChange._(this._bits);

  final int _bits;

  bool get textScaler => (_bits & _GEnvironmentAspect.textScaler) != 0;
  bool get brightness => (_bits & _GEnvironmentAspect.brightness) != 0;
}

/// Lazily consumed host environment for a [GStage].
///
/// Reading a property opts this Stage into tracking only that host property.
/// Unread properties create no MediaQuery dependency.
final class GEnvironment {
  GEnvironment._(this._stage);

  final GStage _stage;

  int _requested = 0;
  int _subscribed = 0;
  TextScaler _textScaler = TextScaler.noScaling;
  Brightness _brightness = Brightness.light;

  TextScaler get textScaler {
    _consume(_GEnvironmentAspect.textScaler);
    return _textScaler;
  }

  Brightness get brightness {
    _consume(_GEnvironmentAspect.brightness);
    return _brightness;
  }

  bool get dark => brightness == Brightness.dark;

  bool get _needsHostSync => _requested != _subscribed;

  void _consume(int aspect) {
    if ((_requested & aspect) != 0) return;
    _requested |= aspect;

    final context = _stage._flutterContext;
    if (context != null) _seed(context, aspect);
    _stage._environmentRequirementsChanged();
  }

  void _seed(BuildContext context, int aspect) {
    final data = context.getInheritedWidgetOfExactType<MediaQuery>()?.data;
    if ((aspect & _GEnvironmentAspect.textScaler) != 0) {
      _textScaler = data?.textScaler ?? TextScaler.noScaling;
    }
    if ((aspect & _GEnvironmentAspect.brightness) != 0) {
      _brightness = data?.platformBrightness ?? Brightness.light;
    }
  }

  int _sync(BuildContext context) {
    final requested = _requested;
    if (requested == 0) return 0;

    var changed = 0;
    if ((requested & _GEnvironmentAspect.textScaler) != 0) {
      final next = MediaQuery.textScalerOf(context);
      if (next != _textScaler) {
        _textScaler = next;
        changed |= _GEnvironmentAspect.textScaler;
      }
    }
    if ((requested & _GEnvironmentAspect.brightness) != 0) {
      final next = MediaQuery.platformBrightnessOf(context);
      if (next != _brightness) {
        _brightness = next;
        changed |= _GEnvironmentAspect.brightness;
      }
    }

    _subscribed = requested;
    return changed;
  }
}
