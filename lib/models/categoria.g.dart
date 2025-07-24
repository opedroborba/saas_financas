// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categoria.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Categoria _$CategoriaFromJson(Map<String, dynamic> json) => Categoria(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      nome: json['nome'] as String,
      tipo: json['tipo'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$CategoriaToJson(Categoria instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'nome': instance.nome,
      'tipo': instance.tipo,
      'created_at': instance.createdAt.toIso8601String(),
    };
