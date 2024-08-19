import SwiftUI

struct GameView: View {
    @State private var playerPaddlePosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 200)
    @State private var computerPaddlePosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: 100)
    @State private var ballPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
    @State private var ballDirection = CGSize(width: 5, height: 5)
    @State private var playerScore = 0
    @State private var computerScore = 0
    @State private var ballSpeed: CGFloat = 5.0
    @State private var gameTimer: Timer?
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Player Paddle
                Rectangle()
                    .frame(width: 100, height: 20)
                    .position(playerPaddlePosition)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                playerPaddlePosition.x = value.location.x
                            }
                    )
                
                // Computer Paddle
                Rectangle()
                    .frame(width: 100, height: 20)
                    .position(computerPaddlePosition)
                
                // Ball
                Circle()
                    .frame(width: 20, height: 20)
                    .position(ballPosition)
                
                // Player Score
                Text("Player: \(playerScore)")
                    .foregroundColor(.white)
                    .font(.largeTitle)
                    .position(x: geo.size.width / 2, y: geo.size.height - 50)
                
                // Computer Score
                Text("Computer: \(computerScore)")
                    .foregroundColor(.white)
                    .font(.largeTitle)
                    .position(x: geo.size.width / 2, y: 50)
            }
            .onAppear(perform: {
                startGame()
            })
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
    
    func startGame() {
        resetBall()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            updateBallPosition()
            updateComputerPaddlePosition()
        }
    }
    
    func resetBall() {
        ballPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
        ballDirection = CGSize(width: ballSpeed, height: ballSpeed)
        ballSpeed = 5.0
    }
    
    func updateBallPosition() {
        ballPosition.x += ballDirection.width
        ballPosition.y += ballDirection.height
        
        // Ball collision with walls
        if ballPosition.x <= 10 || ballPosition.x >= UIScreen.main.bounds.width - 10 {
            ballDirection.width = -ballDirection.width
        }
        
        // Ball collision with player paddle
        if ballPosition.y >= playerPaddlePosition.y - 10 &&
            ballPosition.x >= playerPaddlePosition.x - 50 &&
            ballPosition.x <= playerPaddlePosition.x + 50 {
            ballDirection.height = -ballDirection.height
            increaseBallSpeed()
        }
        
        // Ball collision with computer paddle
        if ballPosition.y <= computerPaddlePosition.y + 10 &&
            ballPosition.x >= computerPaddlePosition.x - 50 &&
            ballPosition.x <= computerPaddlePosition.x + 50 {
            ballDirection.height = -ballDirection.height
            increaseBallSpeed()
        }
        
        // Ball goes out of bounds
        if ballPosition.y <= 0 {
            // Player scores
            playerScore += 1
            resetBall()
        } else if ballPosition.y >= UIScreen.main.bounds.height {
            // Computer scores
            computerScore += 1
            resetBall()
        }
    }
    
    func updateComputerPaddlePosition() {
        if ballPosition.x > computerPaddlePosition.x {
            computerPaddlePosition.x += min(ballSpeed, 5)
        } else if ballPosition.x < computerPaddlePosition.x {
            computerPaddlePosition.x -= min(ballSpeed, 5)
        }
    }
    
    func increaseBallSpeed() {
        ballSpeed += 0.5
        ballDirection = CGSize(width: ballDirection.width * 1.05, height: ballDirection.height * 1.05)
    }
}
