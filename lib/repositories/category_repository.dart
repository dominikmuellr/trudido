import '../models/category.dart';
import '../services/storage_service.dart';

class CategoryRepository {
  Future<List<Category>> loadAll() async {
    return Future.value(StorageService.getAllCategories());
  }

  Future<void> save(Category category) async {
    await StorageService.saveCategory(category);
  }

  Future<void> delete(String id) async {
    await StorageService.deleteCategory(id);
  }
}
