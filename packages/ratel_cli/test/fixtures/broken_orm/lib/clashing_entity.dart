import 'package:ratel_orm/ratel_orm.dart';

@Entity()
final class ClashingEntity {
  const ClashingEntity({
    required this.id,
    required this.ownerId,
    required this.owner,
  });

  @Id()
  final int id;
  final int ownerId;
  @Column(name: 'owner_id')
  final int owner;
}
