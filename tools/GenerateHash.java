import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

public class GenerateHash {
    public static void main(String[] args) {
        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(12); // strength 12
        String password = "Mother-Child-1";
        String hashed = encoder.encode(password);
        System.out.println("BCrypt hash: " + hashed);
    }
}
