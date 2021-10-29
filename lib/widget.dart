part of lazyload;
typedef PaginatedData<T> = Future<List<T>> Function(int page, BuildContext context);
typedef _GetterDelegate<T> = T Function();

class FetchController<T> with ChangeNotifier{

  _GetterDelegate<void> _refresh = (){};
  _GetterDelegate<int> _currentPage = () => 0;
  _GetterDelegate<bool> _isLoading = () => true;
  _GetterDelegate<bool> _isError = () => false;

  void _update(){
    if(SchedulerBinding.instance != null)
      SchedulerBinding.instance?.addPostFrameCallback((timeStamp) {notifyListeners();});
    else
      notifyListeners();
  }

  set _setRefresh(_GetterDelegate<void> refreshDelegate){
    _refresh = refreshDelegate;
  }
  set _setCurrentPage(_GetterDelegate<int> currentPageDelegate){
    _currentPage = currentPageDelegate;
  }
  set _setIsLoading(_GetterDelegate<bool> loadingDelegate){
    _isLoading = loadingDelegate;
  }
  set _setIsError(_GetterDelegate<bool> isErrorDelegate){
    _isLoading = isErrorDelegate;
  }

  void _init(
    {
      required _GetterDelegate<void> refreshDelegate,
      required _GetterDelegate<int> pageDelegate,
      required _GetterDelegate<bool> loadingDelegate,
      required _GetterDelegate<bool> isErrorDelegate,
    }
  ){
    _setRefresh = refreshDelegate;
    _setCurrentPage = pageDelegate;
    _setIsLoading = loadingDelegate;
    _setIsError = isErrorDelegate;
    _update();
  }

  @visibleForTesting
  void init(
    {
      required _GetterDelegate<void> refreshDelegate,
      required _GetterDelegate<int> pageDelegate,
      required _GetterDelegate<bool> loadingDelegate,
      required _GetterDelegate<bool> isErrorDelegate,
    }
  ){
    _init(refreshDelegate: refreshDelegate, pageDelegate: pageDelegate, loadingDelegate: loadingDelegate, isErrorDelegate: isErrorDelegate);
  }

  @override
  void dispose() {
    if(SchedulerBinding.instance == null)
      super.dispose();
    else 
      SchedulerBinding.instance?.addPostFrameCallback((timeStamp) {super.dispose();});
  }

  void refresh(){ _refresh(); }
  bool get isLoading => _isLoading();
  bool get isError => _isError();
  int get currentPage => _currentPage();

}


class LazyLoadView<T> extends StatefulWidget {
  LazyLoadView({
    Key? key,
    required this.data,
    this.fetchController,
    this.before = const [],
    this.after = const [],
    this.contentPadding = const EdgeInsets.all(0),
    required this.loaderWidget,
    required this.loadMoreWidget,
    required this.errorWidget,
    required this.errorOnLoadMoreWidget,
    this.scrollPhysics,
    required this.itemBuilder,
    this.pageFactor = 10,
    this.gridDelegate,
    this.emptyWidget = const SliverToBoxAdapter(),
    this.needBottomSpace = true,
    this.needPagination = true,
    this.overridePullToRefresh
  }) 
    : super(key: key);

  final FetchController<T>? fetchController;
  final PaginatedData<T> data;
  final List<Widget> before;
  final List<Widget> after;
  final EdgeInsets contentPadding;
  final Widget loaderWidget;
  final Widget loadMoreWidget;
  final SliverGridDelegate? gridDelegate;
  final Widget Function(void Function() closure, dynamic e) errorWidget;
  final Widget Function(void Function() closure, dynamic e) errorOnLoadMoreWidget;
  final ScrollPhysics? scrollPhysics;
  final Widget Function(BuildContext context, T model, int index) itemBuilder;
  final int pageFactor;
  final Widget emptyWidget;
  final bool needBottomSpace;
  final bool needPagination;
  final void Function()? overridePullToRefresh;

  @override
  LazyLoadViewState<T> createState() => LazyLoadViewState<T>();
}

class LazyLoadViewState<_T> extends State<LazyLoadView<_T>> with _StreamControlledMixin<LazyLoadView<_T>, _T>{

  late int _pagefactor;
  List<_T> _data = [];
  bool _isError = false;
  StreamSubscription? _channel;
  bool get _isErrorOnLoadMore => _data.isNotEmpty && _isError;
  bool get _isLoadingMore => _data.isNotEmpty && isLoading;
  late ScrollController controller;
  dynamic errorTrace;
  bool performingFrame = false;

  List<_T> get data =>  [..._data];

  int get _page{
    return (_data.length/_pagefactor).ceil();
  }

  @override
  Future Function() get asyncAction => () => widget.data(_page+1, context);

  @override
    start(_){
      setState(() {
        _isError = false;
        widget.fetchController?._update();
      });
    }

  @override
    done(_){
      widget.fetchController?._update();
    }

  @override
    onDataRecived(cntxt, dataRecieved){
      var finalData = dataRecieved as List<_T>;
      setState(() {
        _data.addAll(finalData);
        widget.fetchController?._update();
      });
    }

  @override
    error(_,err){
      setState(() {
        _isError = true;
        errorTrace = err;
        widget.fetchController?._update();
      });
    }

  @override
  void cancel() {
    widget.fetchController?._update();
    _channel?.cancel();
  }

  @override
    get channel => _channel;

  @override
    set channel(v){
      _channel = v
      ?..onDone(()async{
          if(_data.isNotEmpty && widget.needPagination && !performingFrame)
            await Future.delayed(Duration(milliseconds: 570));
          if(mounted){
            setState(() {
              if(performingFrame)
                 performingFrame = false;
               isLoading = false;
               widget.fetchController?._update();
            });
          }
        });
    }

   void _scrollListener() {
    if ( (controller.offset >= controller.position.maxScrollExtent && widget.needPagination)) {
        _loadMore();
    }
  }

  void _loadMore()async{
    if( _data.length == _pagefactor*_page && !isLoading && !_isLoadingMore && !_isError ){
      setState(() {
        widget.fetchController?._update();
        connect(context);
      });
    }
  }

  void refresh(){
    setState(() {
      _data.clear();
      isLoading = true;
      performingFrame = true;
      widget.fetchController?._update();
    });
    connect(context);
  }

  void tryAgain(){
    widget.fetchController?._update();
    connect(context);
  }

  @override
  void dispose() {
    super.dispose();
    cancel();
    isLoading = false;
    controller.dispose();
    channel?.cancel();
  }

  int _getPage() => _page;
  bool _getIsLoading() => isLoading;
  bool _getIsError() => _isError;

  @override
  void initState() {
    super.initState();
    _pagefactor = widget.pageFactor;
    SchedulerBinding.instance?.addPostFrameCallback((timeStamp) { 
      if(widget.fetchController != null){
        widget.fetchController?._init(
          refreshDelegate: refresh, 
          pageDelegate: _getPage, 
          loadingDelegate: _getIsLoading, 
          isErrorDelegate: _getIsError
        );
      }
    });
    controller = ScrollController()..addListener(_scrollListener);
    connect(context);
  }
  

  @override
  Widget build(BuildContext context) {

    return Container(
       child: RefreshIndicator(
         onRefresh: ()async{ 
           if(widget.overridePullToRefresh == null)
            refresh();
           else 
            widget.overridePullToRefresh!();
         },
         child: CustomScrollView(
           physics: isLoading && !_isLoadingMore? NeverScrollableScrollPhysics(): widget.scrollPhysics,
           controller: controller,
           slivers: [

             if(isLoading && _data.isEmpty)
              widget.loaderWidget
             else if(_isError && _data.isEmpty)
              widget.errorWidget(refresh, errorTrace)
             else if(_data.isEmpty)
              widget.emptyWidget
             else if(widget.gridDelegate != null)
             SliverPadding(
               padding: widget.contentPadding,
               sliver: SliverGrid(
                 delegate: SliverChildBuilderDelegate(
                   (_, index) => widget.itemBuilder(context, _data[index], index),
                   childCount: _data.length
                 ), 
                 gridDelegate: widget.gridDelegate!
               ),
             ) 
             else
              SliverPadding(
                padding: widget.contentPadding,
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    List.generate(
                      _data.length, 
                      (index) => widget.itemBuilder(context,_data[index], index)
                    )
                  ),
                ),
              ),
             if(_isLoadingMore)
              widget.loadMoreWidget
             else if(_isErrorOnLoadMore)
              widget.errorOnLoadMoreWidget(tryAgain, errorTrace)
           ]..insertAll(
             0, 
             widget.before
           )..addAll(
             [
               if(!isLoading && !_isLoadingMore)
               ...widget.after
             ]
           )..addAll([
             if(widget.needBottomSpace)
             SliverToBoxAdapter(
               child: SizedBox(
                 height: (MediaQuery.of(context).size.height*0.1)/2,
               ),
             )
           ]),
         ),
       ),
    );
  }
}