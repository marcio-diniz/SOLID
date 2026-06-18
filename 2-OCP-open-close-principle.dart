// ignore_for_file: uri_does_not_exist, unused_import, undefined_class, undefined_method, undefined_identifier, non_type_as_type_argument

// ============================================================
// VERSÃO RUIM — viola o OCP
// ============================================================

class FeedItemWidget extends StatelessWidget {
  final PostEntity post;

  const FeedItemWidget({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Visibility(
          visible:
              post.text != null &&
              post.imageUrl == null &&
              post.videoUrl == null,
          child: TextPostWidget(post),
        ),

        Visibility(
          visible: post.text != null && post.imageUrl != null,
          child: ImageWithTextPostWidget(post),
        ),

        Visibility(
          visible: post.text == null && post.imageUrl != null,
          child: ImagePostWidget(post),
        ),

        Visibility(
          visible: post.videoUrl != null,
          child: VideoPostWidget(post),
        ),
      ],
    );
  }
}

// ============================================================
// VERSÃO NOVA — respeita o OCP
// ============================================================

abstract interface class PostRenderStrategy {
  bool canRender(PostEntity post);

  Widget build(PostEntity post);
}

class TextPostStrategy implements PostRenderStrategy {
  @override
  bool canRender(PostEntity post) {
    return post.text != null && post.imageUrl == null && post.videoUrl == null;
  }

  @override
  Widget build(PostEntity post) {
    return TextPostWidget(post);
  }
}

class ImagePostStrategy implements PostRenderStrategy {
  @override
  bool canRender(PostEntity post) {
    return post.imageUrl != null && post.text == null && post.videoUrl == null;
  }

  @override
  Widget build(PostEntity post) {
    return ImagePostWidget(post);
  }
}

class ImageWithTextStrategy implements PostRenderStrategy {
  @override
  bool canRender(PostEntity post) {
    return post.imageUrl != null && post.text != null && post.videoUrl == null;
  }

  @override
  Widget build(PostEntity post) {
    return ImageWithTextPostWidget(post);
  }
}

class VideoPostStrategy implements PostRenderStrategy {
  @override
  bool canRender(PostEntity post) {
    return post.videoUrl != null;
  }

  @override
  Widget build(PostEntity post) {
    return VideoPostWidget(post);
  }
}

class PostRenderer {
  final List<PostRenderStrategy> strategies;

  const PostRenderer({required this.strategies});

  Widget build(PostEntity post) {
    final strategy = strategies.firstWhere(
      (strategy) => strategy.canRender(post),
      orElse: () {
        _crashlytics.log(
          'Nenhuma estratégia de renderização encontrada para o post ${post.id}',
        );
        return SizedBox.shrink();
      },
    );

    return strategy.build(post);
  }
}

class FeedListPostWidget extends StatelessWidget {
  final List<PostEntity> posts;

  FeedListPostWidget({required this.posts});
  final renderer = PostRenderer(
    strategies: [
      VideoPostStrategy(),
      ImageWithTextStrategy(),
      ImagePostStrategy(),
      TextPostStrategy(),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return renderer.build(posts[index]);
      },
    );
  }
}
