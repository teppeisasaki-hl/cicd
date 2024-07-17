FROM golang:1.22 as builder

WORKDIR /app

COPY ./app/go.* ./
RUN go mod download
COPY ./app/ ./
RUN CGO_ENABLED=0 go build -v -o main ./main.go

FROM gcr.io/distroless/static:nonroot 
COPY --from=builder --chown=nonroot:nonroot /app/main /main

EXPOSE 8080
CMD ["/main"]
