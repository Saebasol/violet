// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pimp_my_button/pimp_my_button.dart';
import 'package:provider/provider.dart';
import 'package:violet/component/hentai.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/model/article_info.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/article_info/article_info_page.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/image_provider_manager.dart';
import 'package:violet/widgets/article_item/thumbnail.dart';
import 'package:violet/widgets/article_item/thumbnail_view_page.dart';

typedef void BookmarkCallback(int article);
typedef void BookmarkCheckCallback(int article, bool check);

class ArticleListItemVerySimpleWidget extends StatefulWidget {
  // final bool addBottomPadding;
  // final bool showDetail;
  // final QueryResult queryResult;
  // final double width;
  // final String thumbnailTag;
  // final bool bookmarkMode;
  // final BookmarkCallback bookmarkCallback;
  // final BookmarkCheckCallback bookmarkCheckCallback;
  bool isChecked;
  final bool isCheckMode;

  ArticleListItemVerySimpleWidget({
    // this.queryResult,
    // this.addBottomPadding,
    // this.showDetail,
    // this.width,
    // this.thumbnailTag,
    // this.bookmarkMode = false,
    // this.bookmarkCallback,
    // this.bookmarkCheckCallback,
    this.isChecked = false,
    this.isCheckMode = false,
  });

  @override
  _ArticleListItemVerySimpleWidgetState createState() =>
      _ArticleListItemVerySimpleWidgetState();
}

class _ArticleListItemVerySimpleWidgetState
    extends State<ArticleListItemVerySimpleWidget>
    with TickerProviderStateMixin {
  ArticleListItem data;

  String thumbnail;
  int imageCount = 0;
  double pad = 0.0;
  double scale = 1.0;
  bool onScaling = false;
  AnimationController scaleAnimationController;
  bool isBlurred = false;
  bool disposed = false;
  bool isBookmarked = false;
  bool animating = false;
  bool isLastestRead = false;
  bool disableFiltering = false;
  int latestReadPage = 0;
  Map<String, String> headers;
  final FlareControls _flareController = FlareControls();

  @override
  void initState() {
    super.initState();
  }

  String artist;
  String title;
  String dateTime;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
    scaleAnimationController.dispose();
  }

  bool firstChecked = false;

  bool _inited = false;

  _init() {
    if (_inited) return;
    _inited = true;

    data = Provider.of<ArticleListItem>(context);
    disableFiltering = (data.disableFilter != null && data.disableFilter);

    _initAnimations();
    _checkIsBookmarked();
    _checkLastRead();
    _initTexts();
    _setProvider();
  }

  _initAnimations() {
    scaleAnimationController = AnimationController(
      vsync: this,
      lowerBound: 1.0,
      upperBound: 1.08,
      duration: Duration(milliseconds: 180),
    );
    scaleAnimationController.addListener(() {
      setState(() {
        scale = scaleAnimationController.value;
      });
    });
  }

  _checkIsBookmarked() {
    Bookmark.getInstance().then((value) async {
      isBookmarked = await value.isBookmark(data.queryResult.id());
      if (isBookmarked) setState(() {});
    });
  }

  _checkLastRead() {
    User.getInstance().then((value) => value.getUserLog().then((value) async {
          var x = value.where((e) =>
              e.articleId() == data.queryResult.id().toString() &&
              e.lastPage() != null &&
              e.lastPage() > 1 &&
              DateTime.parse(e.datetimeStart())
                      .difference(DateTime.now())
                      .inDays <
                  31);
          if (x.length == 0) return;
          setState(() {
            isLastestRead = true;
            latestReadPage = x.first.lastPage();
          });
        }));
  }

  _initTexts() {
    artist = (data.queryResult.artists() as String)
        .split('|')
        .where((x) => x.length != 0)
        .join(',');
    if (artist == 'N/A') {
      var group = data.queryResult.groups() != null
          ? data.queryResult.groups().split('|')[1]
          : '';
      if (group != '') artist = group;
    }

    title = HtmlUnescape().convert(data.queryResult.title());
    dateTime = data.queryResult.getDateTime() != null
        ? DateFormat('yyyy/MM/dd HH:mm').format(data.queryResult.getDateTime())
        : '';
  }

  _setProvider() {
    if (!ProviderManager.isExists(data.queryResult.id())) {
      // HitomiManager.getImageList(data.queryResult.id().toString())
      //     .then((images) {
      //   if (images == null) {
      //     return;
      //   }
      //   thumbnail = images.item2[0];
      //   imageCount = images.item2.length;
      //   ThumbnailManager.insert(data.queryResult.id(), images);
      //   if (!disposed) setState(() {});
      // });

      HentaiManager.getImageProvider(data.queryResult).then((value) async {
        thumbnail = await value.getThumbnailUrl();
        imageCount = value.length();
        headers = await value.getHeader(0);
        ProviderManager.insert(data.queryResult.id(), value);
        if (!disposed) setState(() {});
      });
    } else {
      Future.delayed(Duration(milliseconds: 1)).then((v) async {
        var provider = ProviderManager.get(data.queryResult.id());
        thumbnail = await provider.getThumbnailUrl();
        imageCount = provider.length();
        headers = await provider.getHeader(0);
        if (!disposed) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (disposed) return null;
    _init();
    if (data.bookmarkMode &&
        !widget.isCheckMode &&
        !onScaling &&
        scale != 1.0) {
      setState(() {
        scale = 1.0;
      });
    } else if (data.bookmarkMode &&
        widget.isCheckMode &&
        widget.isChecked &&
        scale != 0.95) {
      setState(() {
        scale = 0.95;
      });
    }

    double ww = data.showDetail
        ? data.width - 16
        : data.width - (data.addBottomPadding ? 100 : 0);
    double hh = data.showDetail
        ? 130.0
        : data.addBottomPadding
            ? 500.0
            : data.width * 4 / 3;

    var headers = {
      "Referer": "https://hitomi.la/reader/${data.queryResult.id()}.html/"
    };
    return Container(
      color: widget.isChecked ? Colors.amber : Colors.transparent,
      child: PimpedButton(
          particle: Rectangle2DemoParticle(),
          pimpedWidgetBuilder: (context, controller) {
            return GestureDetector(
              child: SizedBox(
                width: ww,
                height: hh,
                child: AnimatedContainer(
                  // alignment: FractionalOffset.center,
                  curve: Curves.easeInOut,
                  duration: Duration(milliseconds: 300),
                  // padding: EdgeInsets.all(pad),
                  transform: Matrix4.identity()
                    ..translate(ww / 2, hh / 2)
                    ..scale(scale)
                    ..translate(-ww / 2, -hh / 2),
                  child: buildBody(),
                ),
              ),
              // onScaleStart: (detail) {
              //   onScaling = true;
              //   setState(() {
              //     pad = 0;
              //   });
              // },
              // onScaleUpdate: (detail) async {
              //   if (detail.scale > 1.1 &&
              //       !scaleAnimationController.isAnimating &&
              //       !scaleAnimationController.isCompleted) {
              //     scaleAnimationController.forward(from: 1.0);
              //   }
              //   if (detail.scale > 1.1 && !scaleAnimationController.isCompleted) {
              //     var sz = await _calculateImageDimension(thumbnail);
              //     Navigator.of(context).push(PageRouteBuilder(
              //       opaque: false,
              //       transitionDuration: Duration(milliseconds: 500),
              //       pageBuilder: (_, __, ___) => ThumbnailViewPage(
              //         size: sz,
              //         thumbnail: thumbnail,
              //         headers: headers,
              //       ),
              //     ));
              //   }
              // },
              // onScaleEnd: (detail) {
              //   onScaling = false;
              //   scaleAnimationController.reverse();
              // },
              onTapDown: (detail) {
                if (onScaling) return;
                onScaling = true;
                setState(() {
                  // pad = 10.0;
                  scale = 0.95;
                });
              },
              onTapUp: (detail) {
                // if (onScaling) return;
                if (data.selectMode) {
                  data.selectCallback();
                  return;
                }
                onScaling = false;
                if (widget.isCheckMode) {
                  widget.isChecked = !widget.isChecked;
                  data.bookmarkCheckCallback(
                      data.queryResult.id(), widget.isChecked);
                  setState(() {
                    if (widget.isChecked)
                      scale = 0.95;
                    else
                      scale = 1.0;
                  });
                  return;
                }
                if (firstChecked) return;
                setState(() {
                  // pad = 0;
                  scale = 1.0;
                });

                // Navigator.of(context).push(PageRouteBuilder(
                //   // opaque: false,
                //   transitionDuration: Duration(milliseconds: 500),
                //   transitionsBuilder: (BuildContext context,
                //       Animation<double> animation,
                //       Animation<double> secondaryAnimation,
                //       Widget wi) {
                //     // return wi;
                //     return FadeTransition(opacity: animation, child: wi);
                //   },
                //   pageBuilder: (_, __, ___) => ArticleInfoPage(
                //     queryResult: widget.queryResult,
                //     thumbnail: thumbnail,
                //     headers: headers,
                //     heroKey: widget.thumbnailTag,
                //     isBookmarked: isBookmarked,
                //   ),
                // ));
                final height = MediaQuery.of(context).size.height;

                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) {
                    return DraggableScrollableSheet(
                      initialChildSize: 400 / height,
                      minChildSize: 400 / height,
                      maxChildSize: 0.9,
                      expand: false,
                      builder: (_, controller) {
                        return Provider<ArticleInfo>.value(
                          child: ArticleInfoPage(
                            key: ObjectKey('asdfasdf'),
                          ),
                          value: ArticleInfo.fromArticleInfo(
                            queryResult: data.queryResult,
                            thumbnail: thumbnail,
                            headers: headers,
                            heroKey: data.thumbnailTag,
                            isBookmarked: isBookmarked,
                            controller: controller,
                            usableTabList: data.usableTabList,
                          ),
                        );
                      },
                    );
                  },
                );
              },
              onLongPress: () async {
                onScaling = false;
                if (data.bookmarkMode) {
                  if (widget.isCheckMode) {
                    widget.isChecked = !widget.isChecked;
                    setState(() {
                      scale = 1.0;
                    });
                    return;
                  }
                  widget.isChecked = true;
                  firstChecked = true;
                  setState(() {
                    scale = 0.95;
                  });
                  data.bookmarkCallback(data.queryResult.id());
                  return;
                }

                if (isBookmarked) {
                  if (!await showYesNoDialog(context, '북마크를 삭제할까요?', '북마크'))
                    return;
                }
                try {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    duration: Duration(seconds: 2),
                    content: Text(
                      isBookmarked
                          ? '${data.queryResult.id()}${Translations.of(context).trans('removetobookmark')}'
                          : '${data.queryResult.id()}${Translations.of(context).trans('addtobookmark')}',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.grey.shade800,
                  ));
                } catch (e, st) {
                  Logger.error('[ArticleList-LongPress] E: ' +
                      e.toString() +
                      '\n' +
                      st.toString());
                }
                isBookmarked = !isBookmarked;
                if (isBookmarked)
                  await (await Bookmark.getInstance())
                      .bookmark(data.queryResult.id());
                else
                  await (await Bookmark.getInstance())
                      .unbookmark(data.queryResult.id());
                if (!isBookmarked)
                  _flareController.play('Unlike');
                else {
                  controller.forward(from: 0.0);
                  _flareController.play('Like');
                }
                await HapticFeedback.vibrate();

                // await Vibration.vibrate(duration: 50, amplitude: 50);
                setState(() {
                  pad = 0;
                  scale = 1.0;
                });
              },
              onLongPressEnd: (detail) {
                onScaling = false;
                if (firstChecked) {
                  firstChecked = false;
                  return;
                }
                setState(() {
                  pad = 0;
                  scale = 1.0;
                });
              },
              onTapCancel: () {
                onScaling = false;
                setState(() {
                  pad = 0;
                  scale = 1.0;
                });
              },
              onDoubleTap: () async {
                onScaling = false;
                var sz = await _calculateImageDimension(thumbnail);
                Navigator.of(context).push(PageRouteBuilder(
                  opaque: false,
                  transitionDuration: Duration(milliseconds: 500),
                  transitionsBuilder: (BuildContext context,
                      Animation<double> animation,
                      Animation<double> secondaryAnimation,
                      Widget wi) {
                    return FadeTransition(opacity: animation, child: wi);
                  },
                  pageBuilder: (_, __, ___) => ThumbnailViewPage(
                    size: sz,
                    thumbnail: thumbnail,
                    headers: headers,
                    heroKey: data.thumbnailTag,
                  ),
                ));
                setState(() {
                  pad = 0;
                });
              },
            );
          }),
    );
  }

  Widget buildBody() {
    return Container(
        margin: data.addBottomPadding
            ? data.showDetail
                ? EdgeInsets.only(bottom: 6)
                : EdgeInsets.only(bottom: 50)
            : EdgeInsets.zero,
        decoration: !Settings.themeFlat
            ? BoxDecoration(
                color: data.showDetail
                    ? Settings.themeWhat
                        ? Colors.grey.shade800
                        : Colors.white70
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.all(Radius.circular(3)),
                boxShadow: [
                  BoxShadow(
                    color: Settings.themeWhat
                        ? Colors.grey.withOpacity(0.08)
                        : Colors.grey.withOpacity(0.4),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3), // changes position of shadow
                  ),
                ],
              )
            : null,
        color: !Settings.themeFlat || !data.showDetail
            ? null
            : Settings.themeWhat
                ? Colors.black26
                : Colors.white,
        child: data.showDetail
            ? Row(
                children: <Widget>[
                  buildThumbnail(),
                  Expanded(child: buildDetail())
                ],
              )
            : buildThumbnail());
  }

  Widget buildThumbnail() {
    return ThumbnailWidget(
      id: data.queryResult.id().toString(),
      showDetail: data.showDetail,
      thumbnail: thumbnail,
      thumbnailTag: data.thumbnailTag,
      imageCount: imageCount,
      isBookmarked: isBookmarked,
      flareController: _flareController,
      pad: pad,
      isBlurred: isBlurred,
      headers: headers,
      isLastestRead: isLastestRead,
      latestReadPage: latestReadPage,
      disableFiltering: disableFiltering,
    );
  }

  Widget buildDetail() {
    return _DetailWidget(
      artist: artist,
      title: title,
      imageCount: imageCount,
      dateTime: dateTime,
      viewed: data.viewed,
    );
  }

  Future<Size> _calculateImageDimension(String url) {
    Completer<Size> completer = Completer();
    Image image = Image(image: CachedNetworkImageProvider(url));
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          var myImage = image.image;
          Size size = Size(myImage.width.toDouble(), myImage.height.toDouble());
          completer.complete(size);
        },
      ),
    );
    return completer.future;
  }
}

// Artist List Item Details
class _DetailWidget extends StatelessWidget {
  final String title;
  final String artist;
  final int imageCount;
  final String dateTime;
  final int viewed;

  _DetailWidget(
      {this.title, this.artist, this.imageCount, this.dateTime, this.viewed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          Text(
            artist,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.date_range, size: 18),
              Text(
                ' $dateTime',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 2.0),
          Row(
            children: [
              const Icon(Icons.photo, size: 18),
              Text(
                ' $imageCount Page',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4.0),
              if (viewed != null) const Icon(MdiIcons.eyeOutline, size: 18),
              if (viewed != null)
                Text(
                  ' $viewed Viewed',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
