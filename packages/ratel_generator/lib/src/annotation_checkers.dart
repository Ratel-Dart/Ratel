import 'package:source_gen/source_gen.dart';

const _annotations = 'package:ratel/annotations/annotations.dart';

const handlerChecker = TypeChecker.fromUrl(
  'package:ratel/http/handler.dart#RatelHandler',
);
const jsonChecker = TypeChecker.fromUrl('$_annotations#Json');
const columnChecker = TypeChecker.fromUrl(
  'package:ratel_orm/annotations.dart#Column',
);
const controllerChecker = TypeChecker.fromUrl('$_annotations#Controller');
const protectedChecker = TypeChecker.fromUrl('$_annotations#Protected');
const publicChecker = TypeChecker.fromUrl('$_annotations#Public');
const bodyChecker = TypeChecker.fromUrl('$_annotations#Body');
const paramChecker = TypeChecker.fromUrl('$_annotations#Param');
const pathParamChecker = TypeChecker.fromUrl('$_annotations#PathParam');
const headerChecker = TypeChecker.fromUrl('$_annotations#Header');
const cookieChecker = TypeChecker.fromUrl('$_annotations#CookieParam');

const verbCheckers = <(TypeChecker, String)>[
  (TypeChecker.fromUrl('$_annotations#Get'), 'GET'),
  (TypeChecker.fromUrl('$_annotations#Post'), 'POST'),
  (TypeChecker.fromUrl('$_annotations#Put'), 'PUT'),
  (TypeChecker.fromUrl('$_annotations#Delete'), 'DELETE'),
  (TypeChecker.fromUrl('$_annotations#Patch'), 'PATCH'),
  (TypeChecker.fromUrl('$_annotations#Head'), 'HEAD'),
  (TypeChecker.fromUrl('$_annotations#Options'), 'OPTIONS'),
];
