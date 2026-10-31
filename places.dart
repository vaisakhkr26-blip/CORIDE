/// A place the user can pick. The backend needs coordinates to match riders ALONG a route.
class Place {
  final String name;
  final double lat;
  final double lng;
  const Place(this.name, this.lat, this.lng);

  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) => other is Place && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Temporary built-in list of Kerala places so the app works without a maps key.
/// Replace with Google Places / Mapbox search before launch (see README).
const List<Place> kPlaces = [
  Place('Alappuzha', 9.4981, 76.3388),
  Place('Cherthala', 9.6845, 76.3358),
  Place('Kayamkulam', 9.1748, 76.5010),
  Place('Haripad', 9.2833, 76.4667),
  Place('Chengannur', 9.3159, 76.6116),
  Place('Tiruvalla', 9.3844, 76.5741),
  Place('Changanassery', 9.4428, 76.5398),
  Place('Kottayam', 9.5916, 76.5222),
  Place('Pathanamthitta', 9.2648, 76.7870),
  Place('Kollam', 8.8932, 76.6141),
  Place('Karunagappally', 9.0577, 76.5360),
  Place('Kottarakkara', 9.0000, 76.7700),
  Place('Attingal', 8.6966, 76.8150),
  Place('Varkala', 8.7379, 76.7163),
  Place('Thiruvananthapuram', 8.5241, 76.9366),
  Place('Technopark, Thiruvananthapuram', 8.5574, 76.8813),
  Place('Neyyattinkara', 8.3990, 77.0830),
  Place('Kochi', 9.9312, 76.2673),
  Place('Ernakulam', 9.9816, 76.2999),
  Place('Vyttila, Kochi', 9.9680, 76.3187),
  Place('Kakkanad, Kochi', 10.0159, 76.3419),
  Place('Infopark, Kochi', 10.0094, 76.3600),
  Place('Aluva', 10.1004, 76.3570),
  Place('Angamaly', 10.1960, 76.3860),
  Place('Kochi Airport (Nedumbassery)', 10.1520, 76.4019),
  Place('Muvattupuzha', 9.9894, 76.5790),
  Place('Thodupuzha', 9.8958, 76.7183),
  Place('Munnar', 10.0889, 77.0595),
  Place('Chalakudy', 10.3070, 76.3340),
  Place('Thrissur', 10.5276, 76.2144),
  Place('Guruvayur', 10.5945, 76.0410),
  Place('Palakkad', 10.7867, 76.6548),
  Place('Perinthalmanna', 10.9760, 76.2260),
  Place('Malappuram', 11.0510, 76.0711),
  Place('Kozhikode', 11.2588, 75.7804),
  Place('Vadakara', 11.6085, 75.5920),
  Place('Kalpetta', 11.6103, 76.0830),
  Place('Thalassery', 11.7491, 75.4889),
  Place('Kannur', 11.8745, 75.3704),
  Place('Kasaragod', 12.4996, 74.9869),
];
