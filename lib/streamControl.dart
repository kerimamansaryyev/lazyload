part of lazyload;

mixin _StreamControlledMixin<T extends StatefulWidget, D> on State<T>{
  Future Function() get asyncAction;
  StreamSubscription? channel;
  bool isLoading = false;
  void start(BuildContext context){}
  void done(BuildContext context){}
  void error(BuildContext context, dynamic error){}
  void onDataRecived(BuildContext context, D data){}

  void cancel(){
    channel?.cancel();
  }

  void connect(BuildContext ctx){
    cancel();
    this.setState(() {
      start(ctx);
      isLoading = true;
      this.channel = asyncAction().asStream()
        .listen((event){ 
          this.onDataRecived(ctx, event);
        })
        ..onDone((){
           done(ctx);
           if(mounted)
           this.setState(() {
             isLoading = false;
           });
         })
        ..onError((e){
          print('error from generics $e');
          error(ctx, e);
        })
        ;
    });
  }


}