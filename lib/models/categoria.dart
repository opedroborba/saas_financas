import 'package:json_annotation/json_annotation.dart';

part 'categoria.g.dart';

@JsonSerializable()
class Categoria {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String nome;
  final String tipo; // 'receita' ou 'despesa'
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Categoria({
    required this.id,
    required this.userId,
    required this.nome,
    required this.tipo,
    required this.createdAt,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) =>
      _$CategoriaFromJson(json);

  Map<String, dynamic> toJson() => _$CategoriaToJson(this);
}
