import SwiftUI

struct WireframeShowcase: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Main Navigation Flow
                Group {
                    Text("Main Navigation Flow")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 30) {
                            // Onboarding
                            WireframePhone {
                                OnboardingWireframe()
                            }
                            
                            // Home Tab
                            WireframePhone {
                                HomeWireframe()
                            }
                            
                            // Mood Selection
                            WireframePhone {
                                MoodSelectionWireframe()
                            }
                            
                            // Mixtape Generation
                            WireframePhone {
                                MixtapeGenerationWireframe()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Player and Controls Flow
                Group {
                    Text("Player and Controls Flow")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 30) {
                            // Mini Player
                            WireframePhone {
                                MiniPlayerWireframe()
                            }
                            
                            // Full Player
                            WireframePhone {
                                FullPlayerWireframe()
                            }
                            
                            // Queue View
                            WireframePhone {
                                QueueWireframe()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Settings and Profile Flow
                Group {
                    Text("Settings and Profile Flow")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 30) {
                            // Profile
                            WireframePhone {
                                ProfileWireframe()
                            }
                            
                            // Personality Settings
                            WireframePhone {
                                PersonalitySettingsWireframe()
                            }
                            
                            // App Settings
                            WireframePhone {
                                SettingsWireframe()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 40)
        }
    }
}

// Wireframe Phone Container
struct WireframePhone<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        Mockup(type: .mobile) {
            content
                .frame(width: 350, height: 700)
                .background(Color(.systemBackground))
        }
        .frame(width: 350, height: 700)
    }
}

// Individual Wireframe Views
struct OnboardingWireframe: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Circle()
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                )
            
            Text("Welcome to AI Mixtapes")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your smart music companion that adapts to your personality and mood")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: {}) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

struct HomeWireframe: View {
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Text("Home")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Circle()
                    .stroke(Color.secondary, lineWidth: 1)
                    .frame(width: 32, height: 32)
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Current Mood Card
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                        .frame(height: 100)
                        .overlay(
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Current Mood")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("Energetic")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                .padding()
                                Spacer()
                            }
                        )
                    
                    // Recent Mixtapes
                    VStack(alignment: .leading) {
                        Text("Recent Mixtapes")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(0..<3) { _ in
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.secondary.opacity(0.1))
                                        .frame(width: 160, height: 200)
                                }
                            }
                        }
                    }
                    
                    // Recommendations
                    VStack(alignment: .leading) {
                        Text("For You")
                            .font(.headline)
                        
                        ForEach(0..<3) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 70)
                        }
                    }
                }
                .padding()
            }
            
            // Tab Bar
            HStack {
                ForEach(0..<4) { i in
                    Circle()
                        .fill(i == 0 ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .padding()
        }
    }
}

struct MoodSelectionWireframe: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("How are you feeling?")
                .font(.title)
                .fontWeight(.bold)
            
            Circle()
                .stroke(Color.accentColor, lineWidth: 2)
                .frame(width: 150, height: 150)
                .overlay(
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.accentColor, lineWidth: 4)
                        .rotationEffect(.degrees(-90))
                )
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(0..<6) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                        .frame(height: 100)
                }
            }
            .padding()
            
            Spacer()
        }
        .padding(.top, 40)
    }
}

struct MixtapeGenerationWireframe: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Generating Your Mixtape")
                .font(.title2)
                .fontWeight(.bold)
            
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            VStack(alignment: .leading, spacing: 20) {
                ForEach(0..<4) { i in
                    HStack(spacing: 15) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 50, height: 50)
                        
                        VStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 120, height: 16)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 80, height: 14)
                        }
                        
                        Spacer()
                        
                        if i < 2 {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .padding()
            
            Spacer()
            
            Button(action: {}) {
                Text("Cancel")
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)
        }
        .padding(.top, 40)
    }
}

struct MiniPlayerWireframe: View {
    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 15) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading) {
                    Text("Song Title")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Artist")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "play.fill")
                        .font(.title3)
                }
                
                Button(action: {}) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
}

struct FullPlayerWireframe: View {
    var body: some View {
        VStack(spacing: 30) {
            // Album Art
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 280, height: 280)
            
            // Song Info
            VStack(spacing: 8) {
                Text("Song Title")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Artist")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(width: 120, height: 4),
                        alignment: .leading
                    )
                
                HStack {
                    Text("2:15")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("-1:45")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Controls
            HStack(spacing: 40) {
                Button(action: {}) {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }
                
                Button(action: {}) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 64))
                }
                
                Button(action: {}) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }
            }
            
            // Additional Controls
            HStack(spacing: 30) {
                ForEach(["shuffle", "repeat", "list.bullet", "speaker.wave.2"], id: \.self) { icon in
                    Button(action: {}) {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.top, 60)
    }
}

struct QueueWireframe: View {
    var body: some View {
        VStack {
            // Header
            HStack {
                Button(action: {}) {
                    Image(systemName: "chevron.down")
                        .font(.title3)
                }
                
                Spacer()
                
                Text("Up Next")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {}) {
                    Text("Clear")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(0..<8) { i in
                        HStack(spacing: 15) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 50, height: 50)
                            
                            VStack(alignment: .leading) {
                                Text("Song Title")
                                    .font(.subheadline)
                                Text("Artist")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct ProfileWireframe: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Profile Header
                VStack(spacing: 15) {
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Text("Username")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Stats
                HStack(spacing: 30) {
                    ForEach(["Mixtapes", "Following", "Followers"], id: \.self) { stat in
                        VStack {
                            Text("42")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text(stat)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Recent Activity
                VStack(alignment: .leading, spacing: 15) {
                    Text("Recent Activity")
                        .font(.headline)
                    
                    ForEach(0..<4) { _ in
                        HStack(spacing: 15) {
                            Circle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 40, height: 40)
                            
                            VStack(alignment: .leading) {
                                Text("Created a new mixtape")
                                    .font(.subheadline)
                                Text("2 hours ago")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                .padding()
            }
            .padding(.top, 40)
        }
    }
}

struct PersonalitySettingsWireframe: View {
    var body: some View {
        VStack(spacing: 30) {
            Text("Your Music Personality")
                .font(.title2)
                .fontWeight(.bold)
            
            // Personality Description
            Text("Select the personality that best matches your music listening style")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Personality Options
            VStack(spacing: 20) {
                ForEach(0..<3) { i in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(["Explorer", "Curator", "Enthusiast"][i])
                                .font(.headline)
                            Text("Description goes here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Circle()
                            .stroke(i == 0 ? Color.accentColor : Color.secondary, lineWidth: 2)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .fill(i == 0 ? Color.accentColor : Color.clear)
                                    .frame(width: 16, height: 16)
                            )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(i == 0 ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding()
            
            Spacer()
        }
        .padding(.top, 40)
    }
}

struct SettingsWireframe: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 20) {
                    ForEach(["Playback", "Notifications", "Privacy", "Storage", "About"], id: \.self) { section in
                        VStack(alignment: .leading, spacing: 15) {
                            Text(section)
                                .font(.headline)
                            
                            ForEach(0..<2) { _ in
                                HStack {
                                    Text("Setting Option")
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        Divider()
                    }
                }
            }
            .padding()
        }
    }
}

// Preview
struct WireframeShowcase_Previews: PreviewProvider {
    static var previews: some View {
        WireframeShowcase()
    }
}
