# STAGE 1: Build Stage (Uses a pre-installed Gradle image)
FROM gradle:8.10-jdk21-alpine AS build
WORKDIR /app

# Copy only the build files first to leverage Docker caching
COPY build.gradle settings.gradle ./
COPY src ./src

# Build the application - No need to download Gradle!
RUN gradle clean bootJar --no-daemon

# STAGE 2: Runtime Stage (Small, efficient image)
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Copy only the built JAR from the first stage
COPY --from=build /app/build/libs/*.jar app.jar

EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]