FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates python3 python3-venv golang-go nginx protobuf-compiler golang-cfssl curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:/root/go/bin:${PATH}"
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.5 && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN bash scripts/generate.sh && go mod tidy && gofmt -w server && go build -o /usr/local/bin/dice-server ./server
CMD ["bash", "scripts/start.sh"]
