FROM instrumentisto/flutter as builder

COPY . /app
WORKDIR /app

RUN flutter pub get
RUN flutter build web -t lib/main_demo.dart --release

RUN ls -a

FROM scratch
COPY --from=builder /app/build/web /dist
