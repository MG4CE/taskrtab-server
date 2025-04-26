# syntax=docker/dockerfile:1

#Build Stage
FROM golang:1.24.2-alpine3.21 as builder
WORKDIR /usr/src/app
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -v -a -installsuffix cgo -o taskrpad_backend cmd/taskrpad/main.go

#Run Stage
FROM alpine:latest  
RUN apk --no-cache add curl
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder ./usr/src/app/taskrpad_backend ./
EXPOSE 8080
CMD [ "./taskrpad_backend" ]
