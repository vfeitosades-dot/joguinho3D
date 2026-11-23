using UnityEngine;

namespace BlocoQuest
{
    [RequireComponent(typeof(CharacterController))]
    public sealed class PlayerMovement : MonoBehaviour
    {
        public Transform leftLeg;
        public Transform rightLeg;
        public Transform leftArm;
        public Transform rightArm;
        public float walkSpeed = 5f;
        public float runSpeed = 8f;
        public float jumpHeight = 1.4f;
        public float gravity = -24f;

        private CharacterController body;
        private Vector3 velocity;
        private Vector3 spawnPosition;
        private float walkCycle;

        private void Awake()
        {
            body = GetComponent<CharacterController>();
            spawnPosition = transform.position;
        }

        private void Update()
        {
            if (Input.GetKeyDown(KeyCode.R))
                ResetPosition();

            float h = Input.GetAxisRaw("Horizontal");
            float v = Input.GetAxisRaw("Vertical");
            Vector3 input = Vector3.ClampMagnitude(new Vector3(h, 0f, v), 1f);
            Camera gameCamera = Camera.main;

            Vector3 forward = gameCamera ? gameCamera.transform.forward : Vector3.forward;
            Vector3 right = gameCamera ? gameCamera.transform.right : Vector3.right;
            forward.y = 0f;
            right.y = 0f;
            forward.Normalize();
            right.Normalize();

            Vector3 move = (forward * input.z + right * input.x).normalized * input.magnitude;
            bool isRunning = Input.GetKey(KeyCode.LeftShift) || Input.GetKey(KeyCode.RightShift);
            float speed = isRunning ? runSpeed : walkSpeed;

            if (move.sqrMagnitude > 0.01f)
            {
                Quaternion desired = Quaternion.LookRotation(move, Vector3.up);
                transform.rotation = Quaternion.Slerp(transform.rotation, desired, 12f * Time.deltaTime);
            }

            if (body.isGrounded && velocity.y < 0f)
                velocity.y = -2f;

            if (body.isGrounded && Input.GetKeyDown(KeyCode.Space))
                velocity.y = Mathf.Sqrt(jumpHeight * -2f * gravity);

            velocity.y += gravity * Time.deltaTime;
            Vector3 displacement = move * speed + Vector3.up * velocity.y;
            body.Move(displacement * Time.deltaTime);

            float sway = input.magnitude > 0.01f && body.isGrounded ? 1f : 0f;
            walkCycle += Time.deltaTime * (isRunning ? 13f : 9f) * Mathf.Max(.2f, input.magnitude);
            float swing = Mathf.Sin(walkCycle) * 29f * sway;
            if (leftLeg) leftLeg.localRotation = Quaternion.Euler(swing, 0f, 0f);
            if (rightLeg) rightLeg.localRotation = Quaternion.Euler(-swing, 0f, 0f);
            if (leftArm) leftArm.localRotation = Quaternion.Euler(-swing * .75f, 0f, 0f);
            if (rightArm) rightArm.localRotation = Quaternion.Euler(swing * .75f, 0f, 0f);

            if (transform.position.y < -12f)
                ResetPosition();
        }

        private void ResetPosition()
        {
            body.enabled = false;
            transform.position = spawnPosition;
            transform.rotation = Quaternion.identity;
            body.enabled = true;
            velocity = Vector3.zero;
        }
    }
}
