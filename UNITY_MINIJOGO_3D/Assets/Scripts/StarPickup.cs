using UnityEngine;

namespace BlocoQuest
{
    public sealed class StarPickup : MonoBehaviour
    {
        private Vector3 home;
        private float offset;
        private bool collected;

        private void Awake()
        {
            home = transform.position;
            offset = Random.Range(0f, 6.28f);
        }

        private void Update()
        {
            if (collected) return;
            transform.position = home + Vector3.up * Mathf.Sin(Time.time * 2.1f + offset) * .15f;
            transform.Rotate(0f, 85f * Time.deltaTime, 0f, Space.World);
        }

        private void OnTriggerEnter(Collider other)
        {
            if (collected || other.GetComponentInParent<PlayerMovement>() == null)
                return;

            collected = true;
            if (GameSession.Instance != null)
                GameSession.Instance.CollectStar();

            Destroy(gameObject);
        }
    }
}
