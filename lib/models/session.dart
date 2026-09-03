class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final int id;
  final String name;
  final String email;
  final String role;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: _integer(json['id']),
        name: '${json['nome'] ?? 'Usuário'}',
        email: '${json['email'] ?? ''}',
        role: '${json['cargo'] ?? 'Visitante'}',
      );
}

class Company {
  const Company({
    required this.id,
    required this.name,
    this.cnpj,
    this.logoUrl,
    this.email,
    this.phone,
    this.city,
    this.state,
    this.address,
    this.number,
    this.district,
    this.zipCode,
    this.country,
    this.website,
  });

  final int id;
  final String name;
  final String? cnpj;
  final String? logoUrl;
  final String? email;
  final String? phone;
  final String? city;
  final String? state;
  final String? address;
  final String? number;
  final String? district;
  final String? zipCode;
  final String? country;
  final String? website;

  factory Company.fromJson(Map<String, dynamic> json) => Company(
        id: _integer(json['id']),
        name: '${json['nome'] ?? 'Empresa'}',
        cnpj: json['cnpj']?.toString(),
        logoUrl: (json['logoUrl'] ?? json['logo_url'] ?? json['logo'])?.toString(),
        email: json['email']?.toString(),
        phone: json['telefone']?.toString(),
        city: json['cidade']?.toString(),
        state: json['estado']?.toString(),
        address: json['endereco']?.toString(),
        number: json['numero']?.toString(),
        district: json['bairro']?.toString(),
        zipCode: json['cep']?.toString(),
        country: json['pais']?.toString(),
        website: json['site']?.toString(),
      );
}

class Session {
  const Session({
    required this.token,
    required this.user,
    required this.company,
  });

  final String token;
  final UserProfile user;
  final Company company;

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        token: '${json['token'] ?? ''}',
        user: UserProfile.fromJson(
          Map<String, dynamic>.from(json['usuario'] as Map? ?? const {}),
        ),
        company: Company.fromJson(
          Map<String, dynamic>.from(json['empresa'] as Map? ?? const {}),
        ),
      );
}

int _integer(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
