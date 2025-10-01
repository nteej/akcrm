
class User {
  String? id;
  String? name;
  String? email;
  String? registeredDate;
  String? employmentDetails;

  User({this.id, this.name, this.email, this.registeredDate, this.employmentDetails});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      registeredDate: json['created_at']?.toString(),
      employmentDetails: json['employmentDetails']?.toString(),
    );
  }
}
