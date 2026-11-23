using UnityEngine;
using UnityEngine.SceneManagement;

namespace BlocoQuest
{
    public sealed class GameSession : MonoBehaviour
    {
        public static GameSession Instance { get; private set; }
        public int totalStars = 5;
        private int stars;

        private GUIStyle heading;
        private GUIStyle normal;
        private GUIStyle finished;

        private void Awake()
        {
            Instance = this;
        }

        public void CollectStar()
        {
            stars = Mathf.Min(totalStars, stars + 1);
        }

        private void OnGUI()
        {
            if (heading == null)
            {
                heading = new GUIStyle(GUI.skin.label);
                heading.fontSize = 22;
                heading.fontStyle = FontStyle.Bold;
                heading.normal.textColor = Color.white;

                normal = new GUIStyle(GUI.skin.label);
                normal.fontSize = 14;
                normal.normal.textColor = new Color(.82f, .91f, 1f);

                finished = new GUIStyle(heading);
                finished.alignment = TextAnchor.MiddleCenter;
                finished.fontSize = 27;
            }

            float w = Mathf.Min(350f, Screen.width - 24f);
            Rect panel = new Rect(14, 14, w, 117);
            Color original = GUI.color;
            GUI.color = new Color(.075f, .105f, .18f, .9f);
            GUI.DrawTexture(panel, Texture2D.whiteTexture);
            GUI.color = original;

            GUI.Label(new Rect(28, 22, w - 20, 35), "BLOCO QUEST", heading);
            GUI.Label(new Rect(28, 60, w - 20, 28),
                "Estrelas coletadas: " + stars + " / " + totalStars, normal);
            GUI.Label(new Rect(28, 88, w - 20, 26),
                "WASD mover   Shift correr   Espaço pular", normal);

            GUI.Label(new Rect(20, Screen.height - 35, Screen.width - 40, 28),
                "Segure botão direito do mouse para girar a câmera  |  R: reiniciar posição",
                normal);

            if (stars >= totalStars)
            {
                Rect win = new Rect(Screen.width / 2f - 225, Screen.height / 2f - 80, 450, 160);
                GUI.color = new Color(.08f, .18f, .18f, .93f);
                GUI.DrawTexture(win, Texture2D.whiteTexture);
                GUI.color = original;
                GUI.Label(new Rect(win.x + 10, win.y + 25, 430, 50),
                    "TODAS AS ESTRELAS!", finished);
                if (GUI.Button(new Rect(win.x + 140, win.y + 102, 170, 42), "JOGAR DE NOVO"))
                    SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex);
            }
        }
    }
}
