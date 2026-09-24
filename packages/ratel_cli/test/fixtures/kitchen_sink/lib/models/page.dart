final class Page<T> {
  const Page({required this.items, required this.total});

  final List<T> items;
  final int total;
}
