import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class StellarData {
  final List<StellarObject> discoveries = _discoveries;

  StellarObject? getById(String objectId) {
    return discoveries.firstWhereOrNull((obj) => obj.id == objectId);
  }
}

class StellarObject {
  final String name;
  final IconData icon;
  final String description;

  StellarObject({
    required this.name,
    required this.icon,
    required this.description,
  });

  String get id => name.toLowerCase().replaceAll(' ', '_');

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$name: $description';

  @override
  bool operator ==(Object other) => other is StellarObject && other.id == id;
}

final List<StellarObject> _discoveries = [
  StellarObject(
    icon: Icons.whatshot,
    name: 'Betelgeuse',
    description: 'Red supergiant · 700 solar radii',
  ),
  StellarObject(
    icon: Icons.brightness_7,
    name: 'Sirius',
    description: 'Brightest star in the night sky',
  ),
  StellarObject(
    icon: Icons.blur_on,
    name: 'Andromeda',
    description: 'Nearest major galaxy · 2.5 Mly',
  ),
  StellarObject(
    icon: Icons.grain,
    name: 'Orion Nebula',
    description: 'Stellar nursery · 1,344 light-years',
  ),
  StellarObject(
    icon: Icons.circle,
    name: 'Proxima Centauri',
    description: 'Closest star · 4.24 light-years',
  ),
  StellarObject(
    icon: Icons.nights_stay,
    name: 'Pleiades',
    description: 'Open cluster · Seven Sisters',
  ),
  StellarObject(
    icon: Icons.tornado,
    name: 'Pillars of Creation',
    description: 'Eagle Nebula · 6,500 light-years',
  ),
  StellarObject(
    icon: Icons.air,
    name: 'Sagittarius A*',
    description: 'Milky Way central black hole',
  ),
  StellarObject(
    icon: Icons.flare,
    name: 'Eta Carinae',
    description: 'Hypergiant · 5 million solar luminosities',
  ),
];
