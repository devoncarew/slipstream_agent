import 'dart:convert' show jsonEncode;
import 'dart:developer';

final List<ServiceDescription> _registeredExtensions = [];

/// Return a list of all registered service extensions.
List<ServiceDescription> get registeredExtensions =>
    List.unmodifiable(_registeredExtensions);

/// Register a service extension.
void registerServiceExtension(
  ServiceDescription description,
  Future<Object?> Function(ExtensionParameters parameters) handler,
) {
  // Bootstrap the discovery mechanism.
  _registerDiscoveryExtension();

  _registeredExtensions.add(description);

  registerExtension(description.name, (method, parameters) async {
    try {
      final result =
          await handler(ExtensionParameters(parameters, method: method));
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

bool _discoveryRegistered = false;

/// Register a service extension that returns all available service extensions
/// and their metadata.
void _registerDiscoveryExtension() {
  if (_discoveryRegistered) return;
  _discoveryRegistered = true;

  registerServiceExtension(
    ServiceDescription(
      name: 'ext.slipstream.listExtensions',
      description:
          'Returns all available service extensions and their metadata.',
      returns: 'A JSON-encoded list of service extension descriptions.',
    ),
    (parameters) async {
      return registeredExtensions.map((e) => e.toJson()).toList();
    },
  );
}

// API description related

/// A description of a service extension.
class ServiceDescription {
  /// The name of the service extension (e.g. `ext.slipstream.ping`).
  final String name;

  /// A description of the service extension.
  final String description;

  /// A description of the return value.
  ///
  /// A null value here implies no return result / 'void'.
  final String? returns;

  /// The parameters supported by the service extension.
  final List<ParameterDescription> parameters;

  ServiceDescription({
    required this.name,
    required this.description,
    this.returns,
    this.parameters = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      if (returns != null) 'returns': returns,
      'parameters': parameters.map((p) => p.toJson()).toList(),
    };
  }
}

/// A description of a service extension parameter.
class ParameterDescription {
  /// The name of the parameter.
  final String name;

  /// The type of the parameter (e.g. `String`, `int`, `bool`).
  final String type;

  /// A description of the parameter.
  final String description;

  /// Whether the parameter is required.
  final bool required;

  ParameterDescription({
    required this.name,
    required this.type,
    required this.description,
    this.required = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'description': description,
      'required': required,
    };
  }
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
