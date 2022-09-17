import 'package:flutter/cupertino.dart';
import 'package:git_touch/models/theme.dart';
import 'package:git_touch/utils/utils.dart';
import 'package:provider/provider.dart';

import '../widgets/error_reload.dart';
import '../widgets/link.dart';
import '../widgets/loading.dart';

class LongListPayload<T, K> {
  T header;
  int totalCount;
  String? cursor;
  List<K> leadingItems;
  List<K>? trailingItems;

  LongListPayload({
    required this.header,
    required this.totalCount,
    required this.cursor,
    required this.leadingItems,
    this.trailingItems,
  });
}

// This is a scaffold for issue and pull request
// Since the list could be very long, and some users may only want to to check trailing items
// We should load leading and trailing items at first fetching, and do load more in the middle
// e.g. https://github.com/reactjs/rfcs/pull/68
class LongListStatefulScaffold<T, K> extends StatefulWidget {
  final Widget title;
  final Widget Function(T t)? trailingBuilder;
  final Widget Function(T t) headerBuilder;
  final Widget Function(K k) itemBuilder;
  final Future<LongListPayload<T, K>> Function() onRefresh;
  final Future<LongListPayload<T, K>> Function(String? cursor) onLoadMore;

  const LongListStatefulScaffold({
    required this.title,
    this.trailingBuilder,
    required this.headerBuilder,
    required this.itemBuilder,
    required this.onRefresh,
    required this.onLoadMore,
  });

  @override
  _LongListStatefulScaffoldState<T, K> createState() =>
      _LongListStatefulScaffoldState();
}

class _LongListStatefulScaffoldState<T, K>
    extends State<LongListStatefulScaffold<T, K>> {
  late bool loading;
  bool loadingMore = false;
  String error = '';

  LongListPayload<T, K>? payload;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    // Fimber.d('long list scaffold refresh');
    setState(() {
      error = '';
      loading = true;
    });
    try {
      payload = await widget.onRefresh();
    } catch (err) {
      error = err.toString();
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    // Fimber.d('long list scaffold load more');
    setState(() {
      loadingMore = true;
    });
    try {
      LongListPayload<T?, K> p = await widget.onLoadMore(payload!.cursor);
      payload!.totalCount = p.totalCount;
      payload!.cursor = p.cursor;
      payload!.leadingItems.addAll(p.leadingItems);
    } finally {
      if (mounted) {
        setState(() {
          loadingMore = false;
        });
      }
    }
  }

  Widget _buildItem(BuildContext context, int index) {
    final theme = Provider.of<ThemeModel>(context);

    if (index % 2 == 1) {
      return CommonStyle.border;
    }

    int realIndex = index ~/ 2;

    if (realIndex < payload!.leadingItems.length) {
      return widget.itemBuilder(payload!.leadingItems[realIndex]);
    } else if (realIndex == payload!.leadingItems.length) {
      var count = payload!.totalCount -
          payload!.leadingItems.length +
          payload!.trailingItems!.length;
      return Container(
        padding: CommonStyle.padding,
        child: Center(
          child: LinkWidget(
            onTap: _loadMore,
            child: Container(
              padding: CommonStyle.padding,
              decoration: BoxDecoration(
                border: Border.all(color: theme.palette.text),
              ),
              child: Column(
                children: <Widget>[
                  Text('$count hidden items',
                      style:
                          TextStyle(color: theme.palette.text, fontSize: 15)),
                  const Padding(padding: EdgeInsets.only(top: 4)),
                  loadingMore
                      ? const CupertinoActivityIndicator()
                      : Text(
                          'Load more...',
                          style: TextStyle(
                              color: theme.palette.primary, fontSize: 16),
                        ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return widget.itemBuilder(payload!
          .trailingItems![realIndex - payload!.leadingItems.length - 1]);
    }
  }

  int get _itemCount {
    int count = payload!.leadingItems.length + payload!.trailingItems!.length;
    if (payload!.totalCount > count) {
      count++;
    }
    return 2 * count; // including bottom border
  }

  Widget _buildSliver() {
    if (error.isNotEmpty) {
      return SliverToBoxAdapter(
          child: ErrorReload(text: error, onTap: _refresh));
    } else if (loading) {
      // TODO:
      return const SliverToBoxAdapter(child: Loading(more: false));
    } else {
      return SliverList(
        delegate:
            SliverChildBuilderDelegate(_buildItem, childCount: _itemCount),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> slivers = [CupertinoSliverRefreshControl(onRefresh: _refresh)];
    if (payload != null) {
      slivers.add(
        SliverToBoxAdapter(child: widget.headerBuilder(payload!.header)),
      );
    }
    slivers.add(_buildSliver());

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: widget.title,
        trailing:
            payload == null ? null : widget.trailingBuilder!(payload!.header),
      ),
      child: SafeArea(
        child: CupertinoScrollbar(
          child: CustomScrollView(slivers: slivers),
        ),
      ),
    );
  }
}
