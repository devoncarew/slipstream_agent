import 'dart:convert' show jsonEncode;
import 'dart:developer';

void registerServiceExtension(
  String name,
  Future<Object?> Function(ExtensionParameters parameters) handler,
) {
  registerExtension(name, (method, parameters) async {
    try {
      final result =
          await handler(ExtensionParameters(parameters, method: name));
      return ServiceExtensionResponse.result(jsonEncode(result));
    } on ServiceExtensionResponse catch (e) {
      if (e.isError()) {
        return e;
      } else {
        rethrow;
      }
    } catch (e, st) {
      return ServiceExtensionResponse.error(
        ServiceExtensionResponse.extensionError,
        jsonEncode({
          'error': e.toString(),
          'stackTrace': st.toString(),
        }),
      );
    }
  });
}

// API description related

class ServiceDescription {
  // todo:
}

// dispatch related

class ExtensionParameters {
  final String method;
  final Map<String, String> parameters;

  ExtensionParameters(this.parameters, {required this.method});

  /// Return the named parameter as a `String?`; this always succeeds.
  String? asString(String name) => parameters[name];

  /// Return the named parameter as a `String`.
  ///
  /// This will throw a [ServiceExtensionResponse] if the parameter is missing.
  String asStringRequired(String name) {
    if (!parameters.containsKey(name)) {
      throw _missing(name);
    }

    return parameters[name] as String;
  }

  /// Return the named parameter as a `bool?`.
  ///
  /// This will throw if the parameter can't be converted to a `bool?`.
  bool? asBool(String name) {
    if (parameters.containsKey(name)) {
      final result = bool.tryParse(parameters[name]!);
      if (result == null) {
        throw _badType(name, 'bool');
      }
      return result;
    } else {
      return null;
    }
  }

  /// Return the named parameter as a `bool`.
  ///
  /// This will throw a [ServiceExtensionResponse] if the parameter is missing
  /// or if it can't be converted to a `bool`.
  bool asBoolRequired(String name) {
    if (!parameters.containsKey(name)) {
      throw _missing(name);
    }

    final result = bool.tryParse(parameters[name]!);
    if (result == null) {
      throw _badType(name, 'bool');
    }

    return result;
  }

  /// Return the named parameter as an `int?`.
  ///
  /// This will throw if the parameter can't be converted to an `int?`.
  int? asInt(String name) {
    if (parameters.containsKey(name)) {
      final result = int.tryParse(parameters[name]!);
      if (result == null) {
        throw _badType(name, 'int');
      }
      return result;
    } else {
      return null;
    }
  }

  /// Return the named parameter as an `int`.
  ///
  /// This will throw a [ServiceExtensionResponse] if the parameter is missing
  /// or if it can't be converted to an `int`.
  int asIntRequired(String name) {
    if (!parameters.containsKey(name)) {
      throw _missing(name);
    }

    final result = int.tryParse(parameters[name]!);
    if (result == null) {
      throw _badType(name, 'int');
    }

    return result;
  }

  /// Return the named parameter as a `double?`.
  ///
  /// This will throw if the parameter can't be converted to a `double?`.
  double? asDouble(String name) {
    if (parameters.containsKey(name)) {
      final result = double.tryParse(parameters[name]!);
      if (result == null) {
        throw _badType(name, 'double');
      }
      return result;
    } else {
      return null;
    }
  }

  /// Return the named parameter as a `double`.
  ///
  /// This will throw a [ServiceExtensionResponse] if the parameter is missing
  /// or if it can't be converted to a `double`.
  double asDoubleRequired(String name) {
    if (!parameters.containsKey(name)) {
      throw _missing(name);
    }

    final result = double.tryParse(parameters[name]!);
    if (result == null) {
      throw _badType(name, 'double');
    }

    return result;
  }

  ServiceExtensionResponse _missing(String name) {
    return ServiceExtensionResponse.error(
        ServiceExtensionResponse.invalidParams,
        "$method: missing required parameter '$name'");
  }

  ServiceExtensionResponse _badType(String name, String expected) {
    return ServiceExtensionResponse.error(
        ServiceExtensionResponse.extensionError,
        "$method: invalid parameter type for '$name'; expected $expected");
  }
}
