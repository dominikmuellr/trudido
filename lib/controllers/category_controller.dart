import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) => CategoryRepository());

final categoriesProvider = StateNotifierProvider<CategoryController, List<Category>>((ref) {
  return CategoryController(ref.read(categoryRepositoryProvider));
});

class CategoryController extends StateNotifier<List<Category>> {
  final CategoryRepository _repo;
  CategoryController(this._repo) : super(const []) { _init(); }

  Future<void> _init() async {
    state = await _repo.loadAll();
  }

  Future<void> add(Category category) async {
    await _repo.save(category);
    state = [...state, category];
  }

  Future<void> update(Category category) async {
    await _repo.save(category);
    state = [for (final c in state) if (c.id == category.id) category else c];
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    state = state.where((c) => c.id != id).toList();
  }

  Future<void> refresh() async {
    state = await _repo.loadAll();
  }
}
