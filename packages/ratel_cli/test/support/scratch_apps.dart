abstract final class ScratchApps {
  static const newsroom = {
    'lib/models/status.dart': '''
enum Status { draft, published }
''',
    'lib/models/tag.dart': '''
class Tag {
  Tag(this.label, {this.weight = 1.0});

  final String label;
  final double weight;
}
''',
    'lib/models/address.dart': '''
class Address(final String city, final String? zip) {
  String get line => zip == null ? city : '\$zip \$city';
}
''',
    'lib/models/audited.dart': '''
class Audited {
  Audited({required this.createdAt, this.updatedAt});

  final DateTime createdAt;
  final DateTime? updatedAt;
}
''',
    'lib/models/versioned.dart': '''
mixin Versioned {
  int version = 1;
}
''',
    'lib/models/article.dart': '''
import 'address.dart';
import 'audited.dart';
import 'status.dart';
import 'tag.dart';
import 'versioned.dart';

class Article extends Audited with Versioned {
  Article({
    required this.id,
    required this.title,
    required super.createdAt,
    super.updatedAt,
    this.status = Status.draft,
    this.tags = const <Tag>[],
    this.scores = const {'views': 0},
    this.flags = const {},
    this.address,
    this.link,
    this.big,
    this.extra,
  });

  final int id;
  final String title;
  final Status status;
  final List<Tag> tags;
  final Map<String, int> scores;
  final Set<String> flags;
  final Address? address;
  final Uri? link;
  final BigInt? big;
  final Object? extra;
  String? note;
  List<Status?> history = [];

  int get tagCount => tags.length;

  @override
  int get hashCode => id;

  @override
  bool operator ==(Object other) => other is Article && other.id == id;
}
''',
    'lib/models/page.dart': '''
class Page<T> {
  Page(this.items, {required this.total});

  final List<T> items;
  final int total;
}
''',
    'lib/models/summary.dart': '''
class Summary {
  Summary._(this.count);

  factory Summary.of(int count) => Summary._(count);

  final int count;
}
''',
    'lib/models/search.dart': '''
class Search {
  Search({this.query = '', this.limit = 10});

  final String query;
  final int limit;

  (int, int) get window => (0, limit);
}
''',
    'lib/controllers/articles_controller.dart': '''
import 'package:ratel/ratel.dart';

import '../models/article.dart';
import '../models/page.dart';
import '../models/search.dart';
import '../models/summary.dart';
import '../models/tag.dart';

@Controller('/articles')
class ArticlesController {
  @Post('/')
  Future<Response<Article>> create(@Body() Article article) async =>
      Response.json(statusCode: 201, data: article);

  @Get('/')
  Future<Page<Article>> list() async => Page([], total: 0);

  @Get('/tags')
  Future<Response<Page<Tag>>> tags() async =>
      Response.json(data: Page([Tag('news')], total: 1));

  @Get('/stats')
  Future<Map<String, List<Summary>>> stats() async =>
      {'all': [Summary.of(1)]};

  @Post('/search')
  Future<Response> search(@Body() Search search) async =>
      Response.json(data: search);

  @Get('/:id')
  @Put('/:id')
  Future<Article?> byId(@PathParam('id') int id) async => null;

  @Get('/raw')
  Future<Response> raw() async => Response.json(data: {'ok': true});
}
''',
    'bin/probe.dart': r'''
import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:newsroom/models/article.dart';
import 'package:newsroom/models/page.dart';
import 'package:newsroom/models/search.dart';
import 'package:newsroom/models/summary.dart';
import 'package:newsroom/models/tag.dart';

import '../.dart_tool/ratel/build/ratel_app_manifest.dart';

void main() {
  final codecs = JsonCodecs(RatelAppManifest.manifest.jsonCodecs);
  Object? decode(Map<String, Object?> json) {
    try {
      return codecs.forType(Article)!.decode!(json);
    } on BadRequestException catch (error) {
      return error.message;
    }
  }

  Object? encode(Object? value) =>
      jsonDecode(Response.json(data: value).toJson(codecs: codecs));

  const full = {
    'id': 7,
    'title': 'Hi',
    'createdAt': '2024-01-02T03:04:05.000Z',
    'status': 'published',
    'tags': [
      {'label': 'a', 'weight': 2},
      {'label': 'b'},
    ],
    'scores': {'views': 3},
    'flags': ['x', 'x', 'y'],
    'address': {'city': 'Oslo', 'zip': null},
    'link': 'https://x.dev/a',
    'big': '123456789012345678901234567890',
    'extra': {'k': [1]},
    'note': 'n',
    'history': ['draft', null],
    'version': 3,
  };
  const minimal = {
    'id': '7',
    'title': 'T',
    'createdAt': '2024-01-02T03:04:05.000Z',
  };
  final article = decode(full) as Article;
  stdout.writeln(jsonEncode({
    'full': encode(article),
    'minimal': encode(decode(minimal)),
    'missing': decode({...minimal}..remove('id')),
    'date': decode({...minimal, 'createdAt': 'nope'}),
    'nested': decode({
      ...minimal,
      'tags': [
        {'weight': 1},
      ],
    }),
    'enum': decode({...minimal, 'status': 'gone'}),
    'list': decode({...minimal, 'tags': 'a'}),
    'page': encode(Page([article], total: 1)),
    'tagPage': encode(Page([Tag('a')], total: 1)),
    'tagPageDecodes': codecs.forType(Page<Tag>)?.decode != null,
    'stats': encode({
      'all': [Summary.of(3)],
    }),
    'search': encode(Search(query: 'q')),
  }));
}
''',
  };

  static const remoteDtos = {
    'lib/src/remote_point.dart': '''
class RemotePoint {
  RemotePoint({required this.x, required this.y});

  final int x;
  final int y;
}
''',
    'lib/remote_dtos.dart': '''
export 'src/remote_point.dart';
''',
  };

  static const conversions = {
    'lib/models/grade.dart': '''
enum Grade {
  low('LOW'),
  high('HIGH');

  const Grade(this.name);

  final String name;
}
''',
    'lib/models/money.dart': '''
interface class Money {
  Money({required this.amount});

  final int amount;
}
''',
    'lib/models/signup.dart': '''
import 'grade.dart';

class Signup {
  Signup({
    required this.name,
    this.age,
    this.newsletter = false,
    this.grade = Grade.low,
    this.grades = const [Grade.high],
    this.since,
  });

  final String name;
  final int? age;
  final bool newsletter;
  final Grade grade;
  final List<Grade> grades;
  final DateTime? since;
  late String token;
  late final int? rank;
}
''',
    'lib/models/user.dart': '''
class User {
  User(this.firstName);

  factory User.fromJson(Map<String, dynamic> json) =>
      User(json['first_name'] as String);

  final String firstName;

  Map<String, Object?> toJson() => {'first_name': firstName};
}
''',
    'lib/models/account.dart': '''
abstract class Account {
  factory Account(String id) = _Account;

  factory Account.fromJson(Map<String, Object?> json) =>
      _Account(json['id'] as String);

  String get id;

  Map<String, Object?> toJson();
}

class _Account implements Account {
  _Account(this.id);

  @override
  final String id;

  @override
  Map<String, Object?> toJson() => {'account': id};
}
''',
    'lib/models/node.dart': '''
class Node {
  Node(this.name, {this.children = const [], this.parent});

  final String name;
  final List<Node> children;
  final Node? parent;
}
''',
    'lib/models/label.dart': '''
class Label {
  Label(this.text);

  final String text;
}
''',
    'lib/legacy/label.dart': '''
class Label {
  Label(this.code);

  final int code;
}
''',
    'lib/models/pair.dart': '''
import 'package:remote_dtos/remote_dtos.dart';

import '../legacy/label.dart' as legacy;
import 'label.dart';

class Pair {
  Pair(this.label, this.legacyLabel, this.point);

  final Label label;
  final legacy.Label legacyLabel;
  final RemotePoint point;
}
''',
    'lib/conversions_controller.dart': '''
import 'package:ratel/ratel.dart';

import 'models/account.dart';
import 'models/money.dart';
import 'models/node.dart';
import 'models/pair.dart';
import 'models/signup.dart';
import 'models/user.dart';

@Controller('/c')
class ConversionsController {
  @Post('/signup')
  Future<Signup> signup(@Body() Signup signup) async => signup;

  @Post('/money')
  Future<Money> money(@Body() Money money) async => money;

  @Post('/user')
  Future<User> user(@Body() User user) async => user;

  @Post('/account')
  Future<Account> account(@Body() Account account) async => account;

  @Post('/node')
  Future<Node> node(@Body() Node node) async => node;

  @Post('/pair')
  Future<Pair> pair(@Body() Pair pair) async => pair;

  @Get('/raw')
  Future<Response> raw() async => Response.json(data: User('Ada'));
}
''',
    'bin/probe.dart': r'''
import 'dart:convert';
import 'dart:io';

import 'package:conversions/models/account.dart';
import 'package:conversions/models/money.dart';
import 'package:conversions/models/node.dart';
import 'package:conversions/models/pair.dart';
import 'package:conversions/models/signup.dart';
import 'package:conversions/models/user.dart';
import 'package:ratel/ratel.dart';

import '../.dart_tool/ratel/build/ratel_app_manifest.dart';

void main() {
  final codecs = JsonCodecs(RatelAppManifest.manifest.jsonCodecs);

  Object? encode(Object? value) =>
      jsonDecode(Response.json(data: value).toJson(codecs: codecs));

  Object? roundTrip(Type type, Map<String, Object?> json) {
    try {
      return encode(codecs.forType(type)!.decode!(json));
    } on BadRequestException catch (error) {
      return error.message;
    }
  }

  stdout.writeln(jsonEncode({
    'form': roundTrip(Signup, {
      'name': 'Ada',
      'age': '',
      'newsletter': 'on',
      'grade': ' ',
      'grades': ['low'],
      'since': '',
      'token': 't',
      'rank': '',
    }),
    'defaults': roundTrip(Signup, {
      'name': 'Ada',
      'newsletter': null,
      'token': 't',
    }),
    'grade': roundTrip(Signup, {'name': 'Ada', 'grade': 'high', 'token': 't'}),
    'wrongGrade': roundTrip(Signup, {
      'name': 'Ada',
      'grade': 'HIGH',
      'token': 't',
    }),
    'blankRequired': roundTrip(Signup, {'name': '', 'token': 't'}),
    'missingLate': roundTrip(Signup, {'name': 'Ada'}),
    'money': roundTrip(Money, {'amount': 3}),
    'user': roundTrip(User, {'first_name': 'Ada'}),
    'raw': encode(User('Ada')),
    'account': roundTrip(Account, {'id': 'x'}),
    'node': roundTrip(Node, {
      'name': 'a',
      'children': [
        {'name': 'b'},
      ],
    }),
    'pair': roundTrip(Pair, {
      'label': {'text': 't'},
      'legacyLabel': {'code': 1},
      'point': {'x': 1, 'y': 2},
    }),
  }));
}
''',
  };

  static const faulty = {
    'lib/models/shape.dart': '''
abstract class Shape {
  double get area;
}
''',
    'lib/models/line.dart': '''
class Line {
  Line({required this.sku, this.meta});

  final String sku;
  final void Function()? meta;
}
''',
    'lib/models/order.dart': '''
import 'line.dart';
import 'shape.dart';

class Order {
  Order({required this.lines, this.window, this.shape});

  final List<Line> lines;
  final (int, int)? window;
  final Shape? shape;
}
''',
    'lib/models/frozen.dart': '''
class Frozen {
  Frozen.make(this.value);

  final int value;
}
''',
    'lib/models/mismatch.dart': '''
class Mismatch {
  Mismatch(String unknown) : value = unknown.length;

  final int value;
}
''',
    'lib/models/span.dart': '''
class Span {
  const Span(this.seconds);

  final int seconds;
}
''',
    'lib/models/timed.dart': '''
import 'span.dart';

class Timed {
  Timed({this.span = const Span(1)});

  final Span span;
}
''',
    'lib/models/box.dart': '''
class Box<T> {
  Box(this.value);

  final T value;
}
''',
    'lib/models/report.dart': '''
class Report {
  Report(this.title);

  final String title;

  Stream<int> get feed => Stream.value(1);
}
''',
    'lib/models/lenient.dart': '''
class Lenient {
  Lenient({this.name = ''});

  final String name;

  Stream<int> get feed => Stream.value(1);
}
''',
    'lib/models/nest.dart': '''
class Nest<T> {
  Nest(this.value, {this.next});

  final T value;
  final Nest<List<T>>? next;
}
''',
    'lib/models/window.dart': '''
class Window(final (int, int) range, final Stream<int>? feed);
''',
    'lib/legacy.dart': '''
import 'package:ratel/ratel.dart';

@Json()
class Legacy {}
''',
    'lib/faulty_controller.dart': '''
import 'package:ratel/ratel.dart';

import 'models/box.dart';
import 'models/frozen.dart';
import 'models/lenient.dart';
import 'models/mismatch.dart';
import 'models/nest.dart';
import 'models/order.dart';
import 'models/report.dart';
import 'models/shape.dart';
import 'models/timed.dart';
import 'models/window.dart';

@Controller('/faulty')
class FaultyController {
  @Post('/map')
  Future<Response> map(@Body() Map<String, dynamic> body) async =>
      Response.json(data: body);

  @Post('/order')
  Future<Response> order(@Body() Order order) async => Response.json();

  @Get('/shape')
  Future<Shape> shape() async => throw UnimplementedError();

  @Post('/frozen')
  Future<Response> frozen(@Body() Frozen frozen) async => Response.json();

  @Post('/mismatch')
  Future<Response> mismatch(@Body() Mismatch mismatch) async =>
      Response.json();

  @Post('/timed')
  Future<Response> timed(@Body() Timed timed) async => Response.json();

  @Get('/hidden')
  Future<Response<_Hidden>> hidden() async => Response.json();

  @Get('/box')
  Future<Box<T>> box<T>() async => throw UnimplementedError();

  @Get('/report')
  Future<List<Report>> report() async => [];

  @Post('/lenient')
  Future<Response> lenient(@Body() Lenient lenient) async => Response.json();

  @Post('/nest')
  Future<Nest<int>> nest(@Body() Nest<int> nest) async => nest;

  @Post('/window')
  Future<Window> window(@Body() Window window) async => window;
}

class _Hidden {}
''',
  };

  static const samples = {
    'lib/samples.dart': '''
import 'dart:async';

import 'package:ratel/ratel.dart';

enum Tone { soft, loud }

enum _Mood { calm }

class Point(final int x, final int y) {
  int get sum => x + y;
}

class Base {
  Base({required this.id, this.tag = 'a'});

  final int id;
  final String tag;
}

class Derived extends Base {
  Derived({required super.id, super.tag, this.extra = 2});

  final int extra;
}

class Made {
  Made._(this.a);

  factory Made({int a = 1}) => Made._(a);

  final int a;
}

class Named {
  Named.only(this.value);

  final int value;
}

class Needy {
  Needy(this.id, String secret) : hidden = secret.length;

  final int id;
  final int hidden;
}

class Gap {
  Gap(this.a, [int unused = 5, this.b = 0]);

  final int a;
  final int b;
}

class Tail {
  Tail(this.a, {bool verbose = false, int? limit});

  final int a;
}

class Holder<T> {
  Holder(this.value, {this.others = const []});

  final T value;
  final List<T> others;
}

class Mutable {
  Mutable(this.id);

  final int id;
  String name = '';
  late final String locked;
  static int count = 0;
  int _secret = 0;
}

abstract class Shape {}

class Defaults {
  Defaults({
    this.a = 1,
    this.b = 1.5,
    this.c = 'it\\'s \\\$x',
    this.d = true,
    this.e = null,
    this.f = Tone.loud,
    this.g = const [Tone.soft],
    this.h = const {'k': [1]},
    this.i = const {2, 3},
    this.j = const Duration(seconds: 1),
    this.k = double.infinity,
    this.l = 3,
  });

  final int a;
  final double b;
  final String c;
  final bool d;
  final int? e;
  final Tone f;
  final List<Tone> g;
  final Map<String, List<int>> h;
  final Set<int> i;
  final Duration j;
  final double k;
  final double l;
}

typedef Tags = List<String>;

typedef _Secret = List<int>;

extension type Id(int value) {}

class Kinds {
  Kinds(this.parameter);

  final int integer = 0;
  final double real = 0;
  final num number = 0;
  final String string = '';
  final bool boolean = false;
  final DateTime? dateTime = null;
  final Uri? uri = null;
  final BigInt? bigInt = null;
  final Tone tone = Tone.soft;
  final Object? opaque = null;
  final dynamic loose = null;
  final List<int> list = const [];
  final Set<Point> set = const {};
  final Iterable<String> iterable = const [];
  final Map<String, Point?> map = const {};
  final Point? dto = null;
  final Map<int, String> intKeys = const {};
  final (int, int)? record = null;
  final void Function()? function = null;
  final Future<int>? future = null;
  final FutureOr<int>? futureOr = null;
  final Duration? duration = null;
  final Response<Point>? response = null;
  final Shape? shape = null;
  final Id? id = null;
  final Tags tags = const [];
  final _Secret secret = const [];
  final _Mood mood = _Mood.calm;
  final List<Holder<Point?>> nested = const [];
  final Object parameter;
}
''',
  };
}
