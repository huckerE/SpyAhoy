using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class OffsetSky : MonoBehaviour
{
    public Material sky;
    public float distance;

    private void Update()
    {
        Vector2 offset = new Vector2(transform.position.x, transform.position.y) * distance;
        sky.SetVector("_View_Offset", offset);
    }
}
