using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.Rendering;

namespace BlocoQuest.Editor
{
    [InitializeOnLoad]
    public static class SceneBuilder
    {
        private const string SceneAsset = "Assets/Scenes/BlocoQuest.unity";

        static SceneBuilder()
        {
            EditorApplication.delayCall += () =>
            {
                if (Application.isBatchMode || File.Exists(SceneAsset)) return;
                try
                {
                    CreateScene();
                    EditorSceneManager.OpenScene(SceneAsset, OpenSceneMode.Single);
                }
                catch (Exception ex)
                {
                    Debug.LogError("Não foi possível criar a cena inicial: " + ex);
                }
            };
        }

        [MenuItem("Bloco Quest/Criar ou recriar cena")]
        public static void CreateScene()
        {
            Directory.CreateDirectory("Assets/Scenes");
            Directory.CreateDirectory("Assets/Materials");
            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            RenderSettings.fog = false;
            RenderSettings.ambientLight = new Color(.58f, .64f, .74f);
            RenderSettings.ambientMode = AmbientMode.Flat;

            Material grass = Mat("PisoAzul", new Color(.19f, .29f, .37f));
            Material grid = Mat("Grade", new Color(.23f, .38f, .49f));
            Material edge = Mat("Bordas", new Color(.09f, .15f, .24f));
            Material platform = Mat("Plataformas", new Color(.31f, .46f, .57f));
            Material shirt = Mat("Camiseta", new Color(.12f, .68f, .91f));
            Material pants = Mat("Calca", new Color(.12f, .19f, .32f));
            Material skin = Mat("Pele", new Color(.94f, .73f, .53f));
            Material hair = Mat("Cabelo", new Color(.17f, .13f, .16f));
            Material eye = Mat("Olhos", new Color(.02f, .05f, .1f));
            Material star = Mat("Estrela", new Color(1f, .71f, .2f), true);

            CreateWorld(PrimitiveType.Cube, "Chão", new Vector3(0, -.45f, 0),
                new Vector3(50, .9f, 50), grass);

            for (int i = -24; i <= 24; i += 4)
            {
                CreateWorld(PrimitiveType.Cube, "Grade X", new Vector3(i, .015f, 0),
                    new Vector3(.045f, .03f, 50), grid, false);
                CreateWorld(PrimitiveType.Cube, "Grade Z", new Vector3(0, .015f, i),
                    new Vector3(50, .03f, .045f), grid, false);
            }

            CreateWorld(PrimitiveType.Cube, "Borda norte", new Vector3(0, .4f, 25),
                new Vector3(50, .8f, .8f), edge);
            CreateWorld(PrimitiveType.Cube, "Borda sul", new Vector3(0, .4f, -25),
                new Vector3(50, .8f, .8f), edge);
            CreateWorld(PrimitiveType.Cube, "Borda leste", new Vector3(25, .4f, 0),
                new Vector3(.8f, .8f, 50), edge);
            CreateWorld(PrimitiveType.Cube, "Borda oeste", new Vector3(-25, .4f, 0),
                new Vector3(.8f, .8f, 50), edge);

            Vector3[] blocks =
            {
                new Vector3(-5, .6f, 5),
                new Vector3(9, .55f, 0),
                new Vector3(7, .85f, -10),
                new Vector3(-12, .45f, -1),
                new Vector3(-2, .75f, -12),
            };
            for (int i = 0; i < blocks.Length; i++)
                CreateWorld(PrimitiveType.Cube, "Bloco " + (i + 1), blocks[i],
                    new Vector3(2.8f, blocks[i].y * 2f, 2.8f), platform);

            // Personagem original construído de formas básicas da Unity.
            GameObject player = new GameObject("Jogador Humanoide");
            player.layer = 2; // Ignore Raycast para câmera
            player.transform.position = new Vector3(0, 1.04f, 0);
            CharacterController capsule = player.AddComponent<CharacterController>();
            capsule.height = 2f;
            capsule.radius = .33f;
            capsule.center = Vector3.zero;
            capsule.stepOffset = .4f;
            PlayerMovement movement = player.AddComponent<PlayerMovement>();

            CreateChild(PrimitiveType.Cube, "Tronco", player.transform,
                new Vector3(0, -.22f, 0), new Vector3(.58f, .73f, .34f), shirt);
            CreateChild(PrimitiveType.Sphere, "Cabeça", player.transform,
                new Vector3(0, .37f, 0), new Vector3(.46f, .48f, .45f), skin);
            CreateChild(PrimitiveType.Cube, "Cabelo", player.transform,
                new Vector3(0, .65f, 0), new Vector3(.47f, .12f, .46f), hair);
            CreateChild(PrimitiveType.Sphere, "Olho E", player.transform,
                new Vector3(-.105f, .40f, .215f), new Vector3(.058f, .075f, .035f), eye);
            CreateChild(PrimitiveType.Sphere, "Olho D", player.transform,
                new Vector3(.105f, .40f, .215f), new Vector3(.058f, .075f, .035f), eye);
            movement.leftArm = CreateChild(PrimitiveType.Cube, "Braço esquerdo",
                player.transform, new Vector3(-.41f, -.24f, 0),
                new Vector3(.20f, .65f, .26f), shirt).transform;
            movement.rightArm = CreateChild(PrimitiveType.Cube, "Braço direito",
                player.transform, new Vector3(.41f, -.24f, 0),
                new Vector3(.20f, .65f, .26f), shirt).transform;
            movement.leftLeg = CreateChild(PrimitiveType.Cube, "Perna esquerda",
                player.transform, new Vector3(-.16f, -.72f, 0),
                new Vector3(.24f, .55f, .29f), pants).transform;
            movement.rightLeg = CreateChild(PrimitiveType.Cube, "Perna direita",
                player.transform, new Vector3(.16f, -.72f, 0),
                new Vector3(.24f, .55f, .29f), pants).transform;

            foreach (Transform part in player.transform)
                part.gameObject.layer = 2;

            GameObject cameraObject = new GameObject("Câmera terceira pessoa");
            cameraObject.tag = "MainCamera";
            cameraObject.transform.position = new Vector3(0, 5, -7);
            Camera cam = cameraObject.AddComponent<Camera>();
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(.53f, .76f, .91f);
            cam.farClipPlane = 150;
            cameraObject.AddComponent<AudioListener>();
            CameraOrbit orbit = cameraObject.AddComponent<CameraOrbit>();
            orbit.target = player.transform;

            GameObject lightObject = new GameObject("Sol");
            lightObject.transform.rotation = Quaternion.Euler(48, -38, 0);
            Light light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 1.4f;
            light.shadows = LightShadows.Soft;

            Vector3[] positions =
            {
                new Vector3(0, 1.1f, 9),
                new Vector3(-11, 1.1f, -8),
                new Vector3(12, 1.1f, 9),
                new Vector3(-8, 1.1f, 13),
                new Vector3(13, 1.1f, -13)
            };
            for (int i = 0; i < positions.Length; i++)
            {
                GameObject orb = CreateWorld(PrimitiveType.Sphere, "Estrela " + (i + 1),
                    positions[i], new Vector3(.7f, .7f, .7f), star);
                SphereCollider collider = orb.GetComponent<SphereCollider>();
                collider.isTrigger = true;
                Rigidbody body = orb.AddComponent<Rigidbody>();
                body.isKinematic = true;
                body.useGravity = false;
                orb.AddComponent<StarPickup>();
            }

            GameObject session = new GameObject("Interface e objetivo");
            GameSession gameSession = session.AddComponent<GameSession>();
            gameSession.totalStars = positions.Length;

            if (!EditorSceneManager.SaveScene(scene, SceneAsset))
                throw new Exception("Falha ao salvar cena Unity.");

            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(SceneAsset, true)
            };
            AssetDatabase.SaveAssets();
            Debug.Log("Bloco Quest criado: " + SceneAsset);
        }

        private static Material Mat(string name, Color color, bool glow = false)
        {
            string path = "Assets/Materials/" + name + ".mat";
            Material existing = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (existing != null) return existing;

            Shader shader = Shader.Find("Standard");
            if (shader == null) throw new Exception("Shader Standard indisponível.");
            Material material = new Material(shader);
            material.color = color;
            if (glow)
            {
                material.EnableKeyword("_EMISSION");
                material.SetColor("_EmissionColor", color * .7f);
            }
            AssetDatabase.CreateAsset(material, path);
            return material;
        }

        private static GameObject CreateWorld(PrimitiveType type, string name,
            Vector3 position, Vector3 scale, Material material, bool collision = true)
        {
            GameObject obj = GameObject.CreatePrimitive(type);
            obj.name = name;
            obj.transform.position = position;
            obj.transform.localScale = scale;
            obj.GetComponent<Renderer>().sharedMaterial = material;
            if (!collision)
                UnityEngine.Object.DestroyImmediate(obj.GetComponent<Collider>());
            return obj;
        }

        private static GameObject CreateChild(PrimitiveType type, string name,
            Transform parent, Vector3 localPosition, Vector3 scale, Material material)
        {
            GameObject obj = GameObject.CreatePrimitive(type);
            obj.name = name;
            obj.transform.SetParent(parent, false);
            obj.transform.localPosition = localPosition;
            obj.transform.localScale = scale;
            obj.GetComponent<Renderer>().sharedMaterial = material;
            UnityEngine.Object.DestroyImmediate(obj.GetComponent<Collider>());
            return obj;
        }

        [MenuItem("Bloco Quest/Gerar EXE para Windows")]
        public static void BuildWindows()
        {
            CreateScene();
            PlayerSettings.companyName = "BlocoQuest";
            PlayerSettings.productName = "BlocoQuest";
            PlayerSettings.bundleVersion = "1.0";
            PlayerSettings.fullScreenMode = FullScreenMode.Windowed;
            PlayerSettings.defaultScreenWidth = 1280;
            PlayerSettings.defaultScreenHeight = 720;

            string projectRoot = Directory.GetParent(Application.dataPath).FullName;
            string repoRoot = Directory.GetParent(projectRoot).FullName;
            string exePath = Path.Combine(repoRoot, "build", "StandaloneWindows64", "BlocoQuest.exe");
            Directory.CreateDirectory(Path.GetDirectoryName(exePath));

            BuildPlayerOptions options = new BuildPlayerOptions
            {
                scenes = new[] { SceneAsset },
                locationPathName = exePath,
                target = BuildTarget.StandaloneWindows64,
                options = BuildOptions.None
            };
            BuildReport report = BuildPipeline.BuildPlayer(options);
            if (report.summary.result != BuildResult.Succeeded)
                throw new BuildFailedException("O build Windows não foi concluído: " +
                    report.summary.result);
            Debug.Log("Jogo Windows criado: " + exePath);
        }
    }
}
