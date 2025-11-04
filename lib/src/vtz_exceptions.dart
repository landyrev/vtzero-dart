/// Base exception class for all vtzero exceptions
class VtzException implements Exception {
  final String message;

  VtzException(this.message);

  @override
  String toString() => 'VtzException: $message';
}

/// Exception thrown when vector tile encoding isn't valid according to the specification
class VtzFormatException extends VtzException {
  VtzFormatException(super.message);

  @override
  String toString() => 'VtzFormatException: $message';
}

/// Exception thrown when a geometry encoding isn't valid according to the specification
class VtzGeometryException extends VtzFormatException {
  VtzGeometryException(super.message);

  @override
  String toString() => 'VtzGeometryException: $message';
}

/// Exception thrown when a property value is accessed using the wrong type
class VtzTypeException extends VtzException {
  VtzTypeException() : super('wrong property value type');

  @override
  String toString() => 'VtzTypeException: wrong property value type';
}

/// Exception thrown when an unknown version number is found in the layer
class VtzVersionException extends VtzException {
  VtzVersionException(super.message);

  @override
  String toString() => 'VtzVersionException: $message';
}

/// Exception thrown when an index into the key or value table is out of range
class VtzOutOfRangeException extends VtzException {
  VtzOutOfRangeException(super.message);

  @override
  String toString() => 'VtzOutOfRangeException: $message';
}
