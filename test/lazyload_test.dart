import 'package:flutter_test/flutter_test.dart';
import 'package:lazyload/lazyload.dart';

class _RandomClass{

  _RandomClass();

  int _page = 1;
  void refres(){}
  bool _isLoading = true;
  bool _isError = false;

  void change(){
    _page++;
  }

  int _getPage() => _page;
  bool _getIsloading() => _isLoading;
  bool _getIsError() => _isError;

  void init(FetchController controller){
    controller.init(
      refreshDelegate: refres, 
      pageDelegate: _getPage, 
      loadingDelegate: _getIsloading,
      isErrorDelegate: _getIsError
    );
  }
}

void main() {
  test('assigning internal function as a delegate for controller works, result will be 3', () {
    var fetchController = FetchController();
    var random = _RandomClass()..init(fetchController);
    random.change();
    random.change();
    expect(fetchController.currentPage, 3);
  });
}
